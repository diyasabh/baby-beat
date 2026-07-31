import Foundation
import WidgetKit

/// Everything lives in the shared App Group so the app and the widget see the
/// same little heart, the same profile, and the same waiting asks.
enum BeatStore {
    static let appGroup = "group.com.diyasabh.babybeat"
    private static let readingsKey = "beat.readings"
    private static let profileKey = "beat.profile"
    private static let providersKey = "beat.providers"
    private static let requestsKey = "beat.requests"

    static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroup) ?? .standard
    }

    // MARK: Codable plumbing

    private static func read<T: Decodable>(_ key: String, as type: T.Type) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private static func write<T: Encodable>(_ value: T, to key: String) {
        if let data = try? JSONEncoder().encode(value) {
            defaults.set(data, forKey: key)
        }
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: Readings

    /// Newest first.
    static func load() -> [BeatReading] {
        (read(readingsKey, as: [BeatReading].self) ?? []).sorted { $0.date > $1.date }
    }

    static func save(_ readings: [BeatReading]) {
        write(readings, to: readingsKey)
    }

    static func add(_ reading: BeatReading) {
        var readings = load()
        readings.insert(reading, at: 0)
        save(Array(readings.prefix(200)))
    }

    static var latest: BeatReading? { load().first }

    // MARK: Profile

    /// nil until onboarding picks a side.
    static var profile: Profile? {
        get { read(profileKey, as: Profile.self) }
        set {
            if let newValue { write(newValue, to: profileKey) }
            else { defaults.removeObject(forKey: profileKey) }
        }
    }

    static var role: Role? { profile?.role }

    // MARK: Providers (parent side)

    static var providers: [Provider] {
        get { read(providersKey, as: [Provider].self) ?? [] }
        set { write(newValue, to: providersKey) }
    }

    // MARK: Requests

    /// Newest first.
    static var requests: [BeatRequest] {
        get { (read(requestsKey, as: [BeatRequest].self) ?? []).sorted { $0.date > $1.date } }
        set { write(Array(newValue.prefix(100)), to: requestsKey) }
    }

    static var waitingRequests: [BeatRequest] { requests.filter(\.isWaiting) }
}
