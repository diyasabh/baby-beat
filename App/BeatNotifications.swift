import UserNotifications

/// Notes from the app, kept deliberately rare. A calm beat never interrupts:
/// it lands on the widget, where the parent can glance at it whenever they
/// want. Only a worrying beat is allowed to buzz a pocket. The optional
/// nudge covers the other worry, a day that has gone quiet.
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

    /// Called after every saved check, but only a worrying one actually
    /// sends. A good beat is not news, so it stays on the widget and the
    /// parent's day is never interrupted to be told everything is fine.
    func notify(reading: BeatReading) {
        guard reading.mood.isWorrying else { return }

        let content = UNMutableNotificationContent()
        content.title = "please check on baby 💗"
        content.body = "the last beat was \(reading.bpm), \(reading.mood.phrase). if anything feels off, call your pediatrician."
        content.interruptionLevel = .timeSensitive
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
        if let latest {
            content.body = "no new beat from daycare lately. the last one was \(latest.bpm), \(latest.mood.phrase)."
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
