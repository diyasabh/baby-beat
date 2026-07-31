import SwiftUI

/// Baby Beat design tokens. One palette, one type ramp, one motion feel.
/// Every screen and the widget draw from here so nothing reads as a one off.
enum Theme {
    // MARK: Palette
    /// Baby blue sky, top of every screen.
    static let skyTop = Color(red: 0.62, green: 0.83, blue: 0.95)
    /// Softer blue the sky settles into.
    static let skyBottom = Color(red: 0.85, green: 0.94, blue: 0.99)
    /// Thick cloud white.
    static let cloud = Color.white
    /// Heart pink, the emotional center of the app.
    static let heart = Color(red: 1.0, green: 0.52, blue: 0.65)
    /// Deeper pink for gradients and pressed states.
    static let heartDeep = Color(red: 0.95, green: 0.36, blue: 0.53)
    /// Ink blue for primary text. Never pure black.
    static let ink = Color(red: 0.16, green: 0.30, blue: 0.45)
    /// Faded ink for secondary text.
    static let inkSoft = Color(red: 0.16, green: 0.30, blue: 0.45).opacity(0.55)
    /// Butter yellow accent for tiny cheerful details.
    static let butter = Color(red: 1.0, green: 0.87, blue: 0.55)
    /// Alert red for beats that need a parent's eyes right now.
    static let alert = Color(red: 0.86, green: 0.22, blue: 0.27)
    /// Deeper alert red for gradients.
    static let alertDeep = Color(red: 0.68, green: 0.13, blue: 0.19)

    // MARK: Type
    /// Everything is Quicksand (bundled TTF). Four roles only.
    static func title(_ size: CGFloat = 28) -> Font { .custom("Quicksand-Bold", size: size) }
    static func number(_ size: CGFloat = 56) -> Font { .custom("Quicksand-Bold", size: size) }
    static func body(_ size: CGFloat = 16) -> Font { .custom("Quicksand-SemiBold", size: size) }
    static func meta(_ size: CGFloat = 13) -> Font { .custom("Quicksand-Medium", size: size) }

    // MARK: Motion
    /// The house easing. Calm rise, no bounce.
    static let ease = Animation.timingCurve(0.16, 1, 0.3, 1, duration: 0.6)

    /// One full heart cycle in seconds, so the drawn heart beats at the rate
    /// actually being shown. Clamped so a wild reading can't blur into a hum.
    static func beatPeriod(bpm: Int) -> Double {
        min(max(60.0 / Double(max(bpm, 30)), 0.3), 2.0)
    }

    // MARK: Shape
    static let cardRadius: CGFloat = 28
}
