import Foundation
import simd

/// Хранит точки хвоста и управляет логикой затухания.
/// Потокобезопасен: update() вызывается с главного потока,
/// tick()/snapshot() — с потока рендеринга MTKView.
final class TrailManager {

    private var lock = NSLock()
    private var points: [SIMD2<Float>] = []
    private var fadeAlpha: Float = 1.0
    private var movedThisFrame = false

    // MARK: - Main thread

    func update(x: Float, y: Float, maxLength: Int) {
        lock.lock()
        defer { lock.unlock() }

        let newPos = SIMD2<Float>(x, y)

        if let last = points.last {
            let d = simd_length(newPos - last)
            guard d > 1 else { return }   // мышь стоит — fade происходит в tick()

            // Линейная интерполяция при быстром движении
            if d > 10 {
                let steps = Int(d / 5)
                for i in 1..<steps {
                    let t = Float(i) / Float(steps)
                    points.append(last + t * (newPos - last))
                }
            }
        }

        points.append(newPos)
        fadeAlpha = 1.0
        movedThisFrame = true

        if points.count > maxLength {
            points.removeFirst(points.count - maxLength)
        }
    }

    func clear() {
        lock.lock()
        defer { lock.unlock() }
        points.removeAll()
        fadeAlpha = 0
        movedThisFrame = false
    }

    // MARK: - Render thread

    /// Вызывается раз в кадр основным рендерером. Уменьшает fadeAlpha когда мышь стоит.
    func tick(fadeSpeed: Float) {
        lock.lock()
        defer { lock.unlock() }

        if movedThisFrame {
            movedThisFrame = false
            return
        }

        guard !points.isEmpty else { return }

        fadeAlpha = max(0, fadeAlpha - fadeSpeed)
        if fadeAlpha <= 0 {
            points.removeAll()
        }
    }

    /// Потокобезопасный снимок данных для рендеринга.
    func snapshot() -> (points: [SIMD2<Float>], fadeAlpha: Float) {
        lock.lock()
        defer { lock.unlock() }
        return (points, fadeAlpha)
    }
}
