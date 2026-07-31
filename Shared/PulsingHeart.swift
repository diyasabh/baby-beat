import SwiftUI

/// The one heart of the app. A pink heart with soft echo rings that swell
/// outward like a pulse. In the app it beats live at the real bpm; in the
/// widget it holds a gentle phase and breathes between timeline entries.
/// This is the shared signature. Do not invent a second heart.
struct PulsingHeart: View {
    var bpm: Int
    var size: CGFloat = 96
    /// Live animation (app only). Widgets pass false and drive `phase`.
    var animated: Bool = true
    /// 0 or 1, the resting and swollen pose used when not animated.
    var phase: Bool = false
    /// The heart's color pair. Alert states pass alert reds; on the alert
    /// sky the heart goes cloud white instead.
    var tint: Color = Theme.heart
    var tintDeep: Color = Theme.heartDeep

    @State private var beating = false

    private var scaleSmall: CGFloat { 1.0 }
    private var scaleBig: CGFloat { 1.09 }

    var body: some View {
        ZStack {
            echoRing(scale: 1.35, opacity: 0.16)
            echoRing(scale: 1.7, opacity: 0.08)
            Image(systemName: "heart.fill")
                .font(.system(size: size * 0.62))
                .foregroundStyle(
                    LinearGradient(colors: [tint, tintDeep],
                                   startPoint: .top, endPoint: .bottom)
                )
                .shadow(color: tintDeep.opacity(0.35), radius: size * 0.12, y: size * 0.05)
                .scaleEffect(currentScale)
        }
        .frame(width: size, height: size)
        .onAppear {
            guard animated else { return }
            withAnimation(Theme.beat(bpm: bpm).repeatForever(autoreverses: true)) {
                beating = true
            }
        }
    }

    private var currentScale: CGFloat {
        if animated { return beating ? scaleBig : scaleSmall }
        return phase ? scaleBig : scaleSmall
    }

    private func echoRing(scale: CGFloat, opacity: Double) -> some View {
        Circle()
            .fill(tint.opacity(opacity))
            .frame(width: size * 0.62, height: size * 0.62)
            .scaleEffect(scale * (currentScale - 1) * 2 + scale)
    }
}
