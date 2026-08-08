import SwiftUI

/// One heartbeat check, taken wherever baby is and sent home to the parent.
struct BeatReading: Codable, Identifiable, Equatable {
    let id: UUID
    let bpm: Int
    let date: Date
    /// Who counted the beats, e.g. "miss rosie".
    let caregiver: String
    /// Where baby was, e.g. "little clouds daycare".
    let place: String

    init(bpm: Int, date: Date = .now,
         caregiver: String = "miss rosie",
         place: String = "little clouds daycare") {
        self.id = UUID()
        self.bpm = bpm
        self.date = date
        self.caregiver = caregiver
        self.place = place
    }

    var mood: BeatMood { BeatMood(bpm: bpm) }

    /// "miss rosie at little clouds daycare"
    var sender: String { "\(caregiver) at \(place)" }
}

/// How the beat feels, in baby words.
///
/// NOT RENDERED ANYWHERE, on purpose. The capture pipeline is not accurate
/// enough yet to show bpm or interpret wellness, so the UI shows no numbers,
/// no mood words, and no alerts (decided 2026-08-08). This type stays only
/// so stored data and the mapping survive until the pipeline earns it.
enum BeatMood: String, Codable {
    case sleepy
    case cozy
    case bouncy
    /// Worryingly slow.
    case quiet
    /// Worryingly fast.
    case racing

    init(bpm: Int) {
        switch bpm {
        case ..<75: self = .quiet
        case ..<100: self = .sleepy
        case ...160: self = .cozy
        case ...185: self = .bouncy
        default: self = .racing
        }
    }

    /// True when this beat deserves the alert treatment everywhere.
    var isWorrying: Bool { self == .quiet || self == .racing }

    /// Short status word for chips and the widget.
    var word: String {
        switch self {
        case .sleepy: return "sleepy"
        case .cozy: return "cozy"
        case .bouncy: return "bouncy"
        case .quiet: return "quiet"
        case .racing: return "racing"
        }
    }

    /// Gentle full phrase for the dashboard and notifications.
    var phrase: String {
        switch self {
        case .sleepy: return "soft and sleepy"
        case .cozy: return "cozy and steady"
        case .bouncy: return "big and bouncy"
        case .quiet: return "quieter than usual"
        case .racing: return "faster than usual"
        }
    }

    /// The reassurance line the parent actually came for. In an alert it
    /// becomes the ask instead.
    var reassurance: String {
        switch self {
        case .sleepy: return "baby is napping sweetly"
        case .cozy: return "baby is doing just fine"
        case .bouncy: return "someone is having a big play"
        case .quiet, .racing: return "please check on baby now"
        }
    }

    var color: Color {
        switch self {
        case .sleepy: return Color(red: 0.55, green: 0.66, blue: 0.93)
        case .cozy: return Theme.heart
        case .bouncy: return Color(red: 1.0, green: 0.62, blue: 0.36)
        case .quiet, .racing: return Theme.alert
        }
    }
}
