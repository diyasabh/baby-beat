import UserNotifications

/// Notes from the app. Each check sends one soft hello with no numbers and
/// no verdicts, and the optional nudge covers a day that has gone quiet.
/// Nothing here ever interprets baby's health.
final class BeatNotifications: NSObject, UNUserNotificationCenterDelegate {
    static let shared = BeatNotifications()

    private let reminderID = "beat.reminder"
    /// Nudge every four hours when gentle updates are on.
    private let reminderInterval: TimeInterval = 4 * 60 * 60

    func configure() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    /// Called after every saved check: one soft hello that a beat was felt
    /// and shared, nothing more.
    func notify(reading: BeatReading) {
        let content = UNMutableNotificationContent()
        content.title = "a little beat from \(reading.place) 💗"
        content.body = "\(reading.sender) felt a heartbeat and sent it home just now."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1.5, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString,
                                            content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    /// A parent's ask, landing on the caregiver's phone. On one device both
    /// sides share a store, so this is what the caregiver would see.
    func notifyRequest(_ request: BeatRequest, to caregiver: String) {
        let content = UNMutableNotificationContent()
        content.title = "\(request.fromParent) asked for a beat 💗"
        content.body = "when \(request.babyName) is settled, count a little heartbeat and send it home."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1.5, repeats: false)
        let note = UNNotificationRequest(identifier: UUID().uuidString,
                                         content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(note)
    }

    /// The repeating nudge. Re-scheduled after each reading so the copy
    /// always carries the latest beat.
    func setReminders(on: Bool, latest: BeatReading?) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [reminderID])
        guard on else { return }

        let content = UNMutableNotificationContent()
        content.title = "quiet for a little while 🍼"
        if latest != nil {
            content.body = "no new beat from daycare lately. ask for one whenever you like."
        } else {
            content.body = "no beat checks from daycare yet today."
        }
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: reminderInterval, repeats: true)
        let request = UNNotificationRequest(identifier: reminderID, content: content, trigger: trigger)
        center.add(request)
    }

    /// Show banners even while the app is open, so a fresh check is always
    /// visibly celebrated.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
