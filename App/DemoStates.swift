#if DEBUG
import Foundation

/// Known states for capturing the presentation, written through BeatStore so
/// the app and the widget see them exactly as if they had happened for real.
///
/// Two dead ends got us here: seeding the App Group plist from outside loses a
/// race with cfprefsd's cache, and `simctl openurl` puts an "Open in Baby Beat?"
/// dialog over every screenshot. A launch argument has neither problem.
///
///     xcrun simctl launch <device> com.diyasabh.babybeat --demo-state parent_alert
enum DemoState: String, CaseIterable {
    case fresh
    case parentCalm = "parent_calm"
    case parentWaiting = "parent_waiting"
    case parentAlert = "parent_alert"
    case caregiverAsked = "caregiver_asked"
    case caregiverCalmSent = "caregiver_calm_sent"
    case caregiverAlertSent = "caregiver_alert_sent"

    private static let place = "little clouds daycare"
    private static let carer = "miss rosie"

    /// The same believable daycare day the app seeds for itself.
    private var dayHistory: [BeatReading] {
        let cal = Calendar.current
        let now = Date()
        return [(8, 45, 138), (10, 10, 126), (12, 30, 96), (15, 5, 152)]
            .compactMap { hour, minute, bpm in
                guard let date = cal.date(bySettingHour: hour, minute: minute,
                                          second: 0, of: now), date <= now else { return nil }
                return BeatReading(bpm: bpm, date: date,
                                   caregiver: Self.carer, place: Self.place)
            }
    }

    private func justNow(_ bpm: Int) -> BeatReading {
        BeatReading(bpm: bpm, date: Date().addingTimeInterval(-40),
                    caregiver: Self.carer, place: Self.place)
    }

    private func ask(minutesAgo: Int, answered: Bool = false) -> BeatRequest {
        BeatRequest(date: Date().addingTimeInterval(-Double(minutesAgo) * 60),
                    fromParent: "mom", babyName: "baby",
                    answeredAt: answered ? Date() : nil)
    }

    /// Reads `--demo-state <name>` off the launch arguments.
    static func fromLaunchArguments() -> DemoState? {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "--demo-state"), i + 1 < args.count else { return nil }
        return DemoState(rawValue: args[i + 1])
    }

    /// Writes the state into the shared store. Call before the model reads it.
    func write() {
        let parent = Profile(role: .parent, name: "mom",
                             place: Self.place, babyName: "baby")
        let caregiver = Profile(role: .caregiver, name: Self.carer,
                                place: Self.place, babyName: "baby")
        let provider = [Provider(name: Self.carer, place: Self.place)]

        var profile: Profile?
        var readings: [BeatReading] = []
        var providers: [Provider] = []
        var requests: [BeatRequest] = []

        switch self {
        case .fresh:
            break
        case .parentCalm:
            (profile, readings, providers) = (parent, dayHistory + [justNow(113)], provider)
        case .parentWaiting:
            (profile, readings, providers) = (parent, dayHistory + [justNow(113)], provider)
            requests = [ask(minutesAgo: 2)]
        case .parentAlert:
            (profile, readings, providers) = (parent, dayHistory + [justNow(195)], provider)
        case .caregiverAsked:
            // A parent is waiting. The reason a caregiver opens the app at all.
            (profile, readings) = (caregiver, dayHistory)
            requests = [ask(minutesAgo: 8)]
        case .caregiverCalmSent:
            (profile, readings) = (caregiver, dayHistory + [justNow(113)])
            requests = [ask(minutesAgo: 9, answered: true)]
        case .caregiverAlertSent:
            (profile, readings) = (caregiver, dayHistory + [justNow(195)])
            requests = [ask(minutesAgo: 9, answered: true)]
        }

        BeatStore.save(readings.sorted { $0.date > $1.date })
        BeatStore.providers = providers
        BeatStore.requests = requests
        BeatStore.profile = profile
        // Block first-run seeding so it cannot overwrite the captured state.
        BeatStore.defaults.set(profile != nil, forKey: "beat.seeded")
        BeatStore.defaults.set(profile != nil, forKey: "beat.seededAsk")
        if self == .fresh {
            for key in ["beat.seeded", "beat.seededAsk", "beat.reminders"] {
                BeatStore.defaults.removeObject(forKey: key)
            }
        }

    }
}
#endif
