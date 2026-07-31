import SwiftUI

/// The one heart of the app: the hand-drawn crayon heart, beating at the real
/// bpm. Not a sine throb — a lub-dub, so the motion reads as a heartbeat
/// rather than a pulsing dot. In the widget it holds a pose and breathes
/// between timeline entries. This is the shared signature; never add a second
/// heart.
struct PulsingHeart: View {
    var bpm: Int
    var size: CGFloat = 96
    /// Live animation (app only). Widgets pass false and drive `phase`.
    var animated: Bool = true
    /// The resting and swollen pose used when not animated.
    var phase: Bool = false
    /// Tint the drawing instead of letting it keep its own crayon pink.
    /// Alert states pass red; the widget's alert sky passes white.
    var tint: Color?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// One full cycle, so the beat literally runs at the measured rate.
    private var period: Double { Theme.beatPeriod(bpm: bpm) }

    var body: some View {
        Group {
            if animated && !reduceMotion {
                KeyframeAnimator(initialValue: 1.0, repeating: true) { scale in
                    heart.scaleEffect(scale)
                } keyframes: { _ in
                    // lub: the big squeeze
                    CubicKeyframe(1.085, duration: period * 0.12)
                    // ...falls back most of the way
                    CubicKeyframe(1.015, duration: period * 0.13)
                    // dub: the smaller second beat
                    CubicKeyframe(1.055, duration: period * 0.10)
                    // ...settles
                    CubicKeyframe(1.0, duration: period * 0.20)
                    // and rests until the next one
                    LinearKeyframe(1.0, duration: period * 0.45)
                }
            } else {
                heart.scaleEffect(phase ? 1.06 : 1.0)
            }
        }
        .frame(width: size, height: size)
    }

    @ViewBuilder
    private var heart: some View {
        if let tint {
            // Template rendering keeps every crayon stroke, just in one color.
            Image("heart-drawn")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(tint)
        } else {
            Image("heart-drawn")
                .resizable()
                .scaledToFit()
        }
    }
}
