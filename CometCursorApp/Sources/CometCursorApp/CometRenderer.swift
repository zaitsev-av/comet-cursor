import AppKit
import Metal
import MetalKit
import simd

// Вершина quad-сегмента хвоста.
// Должна совпадать с Metal-структурой Vertex в шейдере.
private struct Vertex {
    var position: SIMD2<Float>  // NDC
    var alpha: Float            // прозрачность вдоль хвоста (0..1)
    var edge: Float             // позиция поперёк линии (-1..+1) для soft-edge
}

// Uniforms передаются во фрагментный шейдер.
private struct Uniforms {
    var tailColor: SIMD4<Float>
    var headColor: SIMD4<Float>
}

// Шейдеры компилируются в рантайме из строки,
// чтобы не требовался xcrun metal при сборке через swift build.
private let metalShaderSource = #"""
#include <metal_stdlib>
using namespace metal;

struct Vertex {
    float2 position;
    float  alpha;
    float  edge;
};

struct FragIn {
    float4 position [[position]];
    float  alpha;
    float  edge;
};

struct Uniforms {
    float4 tailColor;
    float4 headColor;
};

vertex FragIn vertex_main(
    uint vid [[vertex_id]],
    device const Vertex* verts [[buffer(0)]])
{
    Vertex v = verts[vid];
    FragIn out;
    out.position = float4(v.position, 0.0, 1.0);
    out.alpha    = v.alpha;
    out.edge     = v.edge;
    return out;
}

fragment float4 fragment_main(
    FragIn in [[stage_in]],
    constant Uniforms& u [[buffer(0)]])
{
    // Плавный falloff от центра к краю линии
    float edgeFalloff = smoothstep(1.0, 0.0, abs(in.edge));

    // Смещённый градиент: больше яркого цвета у головы
    float t = pow(smoothstep(0.0, 1.0, in.alpha), 0.15);
    float3 color = mix(u.tailColor.rgb, u.headColor.rgb, t);

    float alpha = in.alpha * edgeFalloff * 0.92;
    return float4(color, alpha);
}
"""#

final class CometRenderer: NSObject, MTKViewDelegate {

    private let screen: NSScreen
    private let settings: SettingsModel
    private let trailManager: TrailManager
    private let isPrimary: Bool

    private let window: NSPanel
    private let mtkView: MTKView
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private var pipelineState: MTLRenderPipelineState!
    private var keepAliveTimer: Timer?

    // Высота основного экрана для конвертации CGEvent Y↓ → AppKit Y↑
    private let primaryHeight: CGFloat

    init(screen: NSScreen, trailManager: TrailManager, settings: SettingsModel, isPrimary: Bool) {
        self.screen = screen
        self.settings = settings
        self.trailManager = trailManager
        self.isPrimary = isPrimary

        // Основной экран всегда имеет origin (0,0) в AppKit-координатах.
        // NSScreen.main для .accessory-приложений без окон с фокусом возвращает nil,
        // поэтому ищем экран по origin (0,0) напрямую.
        primaryHeight = NSScreen.screens.first(where: { $0.frame.minX == 0 && $0.frame.minY == 0 })?.frame.height
            ?? screen.frame.height

        device = MTLCreateSystemDefaultDevice()!
        commandQueue = device.makeCommandQueue()!

        // NSPanel с .nonactivatingPanel — правильный тип для прозрачных оверлеев:
        // не скрывается при деактивации приложения, не перехватывает фокус клавиатуры.
        window = NSPanel(
            contentRect: CGRect(origin: .zero, size: screen.frame.size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        window.setFrame(screen.frame, display: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        // Screen saver level надёжнее держит overlay поверх обычных окон/space-переходов.
        window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.screenSaverWindow)))
        window.ignoresMouseEvents = true
        window.hidesOnDeactivate = false
        window.isFloatingPanel = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]

        // MTKView на весь контент-фрейм окна
        let viewFrame = CGRect(origin: .zero, size: screen.frame.size)
        mtkView = MTKView(frame: viewFrame, device: device)
        mtkView.autoresizingMask = [.width, .height]
        mtkView.isPaused = false
        mtkView.enableSetNeedsDisplay = false
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.framebufferOnly = false
        mtkView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        mtkView.preferredFramesPerSecond = 60

        if let metalLayer = mtkView.layer as? CAMetalLayer {
            metalLayer.isOpaque = false
            metalLayer.backgroundColor = CGColor(gray: 0, alpha: 0)
        }

        window.contentView = mtkView

        super.init()

        // Pipeline должен быть готов до того, как MTKView начнёт вызывать draw(in:)
        setupPipeline()
        mtkView.delegate = self
        // orderFrontRegardless показывает окно даже когда приложение неактивно (.accessory policy)
        window.orderFrontRegardless()

        // Страховочный таймер: восстанавливает рендер и видимость окна если App Nap
        // или window server их прервали. Работает независимо от draw loop.
        keepAliveTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            if self.mtkView.isPaused { self.mtkView.isPaused = false }
            // isVisible не означает "поверх всех окон", поэтому фронтим регулярно.
            self.window.orderFrontRegardless()
        }
    }

    func orderFront() {
        window.orderFrontRegardless()
    }

    func shutdown() {
        keepAliveTimer?.invalidate()
        keepAliveTimer = nil
        mtkView.delegate = nil
        mtkView.isPaused = true
        window.orderOut(nil)
        window.close()
    }

    // MARK: - Pipeline

    private func setupPipeline() {
        do {
            let library = try device.makeLibrary(source: metalShaderSource, options: nil)
            let vertFn = library.makeFunction(name: "vertex_main")!
            let fragFn = library.makeFunction(name: "fragment_main")!

            let desc = MTLRenderPipelineDescriptor()
            desc.vertexFunction   = vertFn
            desc.fragmentFunction = fragFn
            desc.colorAttachments[0].pixelFormat = .bgra8Unorm

            let ca = desc.colorAttachments[0]!
            ca.isBlendingEnabled             = true
            ca.rgbBlendOperation             = .add
            ca.alphaBlendOperation           = .add
            ca.sourceRGBBlendFactor          = .sourceAlpha
            ca.destinationRGBBlendFactor     = .oneMinusSourceAlpha
            ca.sourceAlphaBlendFactor        = .sourceAlpha
            ca.destinationAlphaBlendFactor   = .oneMinusSourceAlpha

            pipelineState = try device.makeRenderPipelineState(descriptor: desc)
        } catch {
            fatalError("Metal pipeline error: \(error)")
        }
    }

    // MARK: - Coordinate conversion

    /// Конвертирует глобальные координаты CGEvent (origin top-left, Y↓)
    /// в NDC этого конкретного экрана (origin center, Y↑).
    private func toNDC(_ pos: SIMD2<Float>) -> SIMD2<Float> {
        // CGEvent → AppKit (Y flip относительно основного экрана)
        let ax = CGFloat(pos.x)
        let ay = primaryHeight - CGFloat(pos.y)

        // AppKit → NDC с учётом позиции и размера этого экрана
        let ndcX = Float((ax - screen.frame.minX) / screen.frame.width)  * 2 - 1
        let ndcY = Float((ay - screen.frame.minY) / screen.frame.height) * 2 - 1
        return SIMD2<Float>(ndcX, ndcY)
    }

    // MARK: - Vertex generation

    /// Строит непрерывную ленту (triangle strip): каждая точка хвоста
    /// даёт пару вершин (левая/правая), соседние сегменты разделяют вершины —
    /// никаких разрывов в стыках при изменении направления.
    private func buildRibbonVertices(points: [SIMD2<Float>], fadeAlpha: Float) -> [Vertex] {
        guard points.count >= 2 else { return [] }

        let halfW = Float(settings.lineWidth) / 2
        let sw    = Float(screen.frame.width)
        let sh    = Float(screen.frame.height)
        let ndcPts = points.map { toNDC($0) }

        /// Перпендикуляр к вектору (a→b) в NDC, длиной halfW логических пикселей.
        func perp(from a: SIMD2<Float>, to b: SIMD2<Float>) -> SIMD2<Float> {
            let dxPx = (b.x - a.x) * sw / 2
            let dyPx = (b.y - a.y) * sh / 2
            let len  = sqrt(dxPx * dxPx + dyPx * dyPx)
            guard len > 0.001 else { return SIMD2(0, halfW / (sh / 2)) }
            return SIMD2(
                (-dyPx / len) * halfW / (sw / 2),
                ( dxPx / len) * halfW / (sh / 2)
            )
        }

        var verts: [Vertex] = []
        verts.reserveCapacity(ndcPts.count * 2)

        for i in 0..<ndcPts.count {
            let progress = Float(i) / Float(ndcPts.count - 1)
            let alpha    = (0.3 + 0.7 * progress) * fadeAlpha
            let p        = ndcPts[i]

            // Касательная — хорда через соседние точки → гладкий стык без разрыва
            let tangentPerp: SIMD2<Float>
            if i == 0 {
                tangentPerp = perp(from: ndcPts[0], to: ndcPts[1])
            } else if i == ndcPts.count - 1 {
                tangentPerp = perp(from: ndcPts[i - 1], to: ndcPts[i])
            } else {
                tangentPerp = perp(from: ndcPts[i - 1], to: ndcPts[i + 1])
            }

            verts.append(Vertex(position: p - tangentPerp, alpha: alpha, edge: -1))
            verts.append(Vertex(position: p + tangentPerp, alpha: alpha, edge: +1))
        }

        return verts
    }

    // MARK: - MTKViewDelegate

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        // Только основной рендерер тикает затухание (избегаем N-кратного уменьшения)
        if isPrimary {
            trailManager.tick(fadeSpeed: Float(settings.fadeSpeed))
        }

        guard let drawable   = view.currentDrawable,
              let passDesc   = view.currentRenderPassDescriptor,
              let cmdBuf     = commandQueue.makeCommandBuffer() else { return }

        passDesc.colorAttachments[0].clearColor  = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        passDesc.colorAttachments[0].loadAction  = .clear
        passDesc.colorAttachments[0].storeAction = .store

        guard let encoder = cmdBuf.makeRenderCommandEncoder(descriptor: passDesc) else {
            cmdBuf.commit(); return
        }

        let (points, fadeAlpha) = trailManager.snapshot()
        let verts = buildRibbonVertices(points: points, fadeAlpha: fadeAlpha)

        if !verts.isEmpty, let buf = device.makeBuffer(
            bytes: verts,
            length: verts.count * MemoryLayout<Vertex>.stride,
            options: .storageModeShared
        ) {
            var uniforms = Uniforms(
                tailColor: settings.tailColorSIMD,
                headColor: settings.headColorSIMD
            )

            encoder.setRenderPipelineState(pipelineState)
            encoder.setVertexBuffer(buf, offset: 0, index: 0)
            encoder.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 0)
            // triangleStrip: соседние точки разделяют вершины — лента без разрывов
            encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: verts.count)
        }

        encoder.endEncoding()
        cmdBuf.present(drawable)
        cmdBuf.commit()
    }
}
