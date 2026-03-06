import Foundation
import simd

/// Хранит точки хвоста и управляет логикой затухания.
/// Потокобезопасен: update() вызывается с главного потока,
/// tick()/snapshot() — с потока рендеринга MTKView.
final class TrailManager {

    private var lock = NSLock()
    private var points: [SIMD2<Float>] = []
    private var fadeAlpha: Float = 1.0
    private var lastTickTime: TimeInterval?

    // Timestamp последнего движения мыши.
    // Timestamp-подход надёжнее булевого флага:
    // флаг может быть сброшен render-потоком раньше, чем main-поток его взводит.
    private var lastMoveTime: TimeInterval = 0

    // Пауза перед началом затухания (секунды неподвижности мыши).
    private let fadeDelay: TimeInterval = 0.4

    // MARK: - Main thread

    func update(x: Float, y: Float, maxLength: Int) {
        lock.lock()
        defer { lock.unlock() }

        // Всегда обновляем время и alpha, даже если точка не добавляется —
        // это предотвращает fade при медленном движении (d < 1 px между событиями).
        let now = ProcessInfo.processInfo.systemUptime
        lastMoveTime = now
        lastTickTime = now
        fadeAlpha = 1.0

        let newPos = SIMD2<Float>(x, y)

        if let last = points.last {
            let d = simd_length(newPos - last)
            guard d > 1 else { return }  // не добавляем дублирующую точку

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

        if points.count > maxLength {
            points.removeFirst(points.count - maxLength)
        }
    }

    func clear() {
        lock.lock()
        defer { lock.unlock() }
        points.removeAll()
        fadeAlpha = 0
        lastMoveTime = 0
        lastTickTime = nil
    }

    // MARK: - Render thread

    /// Вызывается раз в кадр основным рендерером.
    /// fadeSpeed задаётся как "альфа в секунду", а не "альфа за кадр".
    func tick(fadeSpeed: Float) {
        lock.lock()
        defer { lock.unlock() }

        let now = ProcessInfo.processInfo.systemUptime
        let dt = max(0, now - (lastTickTime ?? now))
        lastTickTime = now

        guard !points.isEmpty else { return }

        let elapsed = now - lastMoveTime
        if elapsed < fadeDelay {
            // Мышь двигалась недавно — держим полную яркость
            fadeAlpha = 1.0
        } else {
            fadeAlpha = max(0, fadeAlpha - fadeSpeed * Float(dt))
            if fadeAlpha <= 0 { points.removeAll() }
        }
    }

    /// Потокобезопасный снимок данных для рендеринга.
    func snapshot() -> (points: [SIMD2<Float>], fadeAlpha: Float) {
        lock.lock()
        defer { lock.unlock() }
        return (points, fadeAlpha)
    }
}
