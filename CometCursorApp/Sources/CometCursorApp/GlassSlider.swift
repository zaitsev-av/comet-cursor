import SwiftUI

struct GlassSlider: View {
    @Binding var value: Double

    let range: ClosedRange<Double>
    let step: Double
    var accent: Color = Color(red: 0.36, green: 0.58, blue: 0.88)

    private let trackHeight: CGFloat = 6
    private let knobSize: CGFloat = 16

    init(value: Binding<Double>, in range: ClosedRange<Double>, step: Double = 0.0) {
        self._value = value
        self.range = range
        self.step = step
    }

    var body: some View {
        GeometryReader { proxy in
            let width = max(proxy.size.width, 1)
            let progress = normalized(value)
            let knobX = progress * width

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.12))
                    .frame(height: trackHeight)
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.10), lineWidth: 0.5)
                    )

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                accent.opacity(0.62),
                                accent.opacity(0.88),
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(knobX, trackHeight), height: trackHeight)

                Circle()
                    .fill(.regularMaterial)
                    .overlay(
                        Circle()
                            .stroke(accent.opacity(0.78), lineWidth: 1.2)
                    )
                    .shadow(color: accent.opacity(0.28), radius: 6, x: 0, y: 0)
                    .frame(width: knobSize, height: knobSize)
                    .offset(x: min(max(knobX - knobSize / 2, 0), width - knobSize))
            }
            .frame(height: knobSize)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        updateValue(locationX: gesture.location.x, width: width)
                    }
            )
        }
        .frame(height: knobSize)
        .accessibilityElement()
        .accessibilityLabel("Slider")
        .accessibilityValue(value.formatted())
        .accessibilityAdjustableAction { direction in
            let delta = step > 0 ? step : (range.upperBound - range.lowerBound) / 100
            switch direction {
            case .increment:
                value = clamped(value + delta)
            case .decrement:
                value = clamped(value - delta)
            @unknown default:
                break
            }
        }
    }

    private func normalized(_ value: Double) -> CGFloat {
        CGFloat((clamped(value) - range.lowerBound) / (range.upperBound - range.lowerBound))
    }

    private func updateValue(locationX: CGFloat, width: CGFloat) {
        let progress = min(max(Double(locationX / width), 0), 1)
        let rawValue = range.lowerBound + progress * (range.upperBound - range.lowerBound)
        value = clamped(stepped(rawValue))
    }

    private func stepped(_ rawValue: Double) -> Double {
        guard step > 0 else { return rawValue }
        return (rawValue / step).rounded() * step
    }

    private func clamped(_ rawValue: Double) -> Double {
        min(max(rawValue, range.lowerBound), range.upperBound)
    }
}
