import SwiftUI

@main
struct BabyBeatApp: App {
    @StateObject private var model = BeatModel()

    init() {
        BeatNotifications.shared.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                .onOpenURL { url in
                    guard url.scheme == "babybeat" else { return }
                    // Only a caregiver can answer with a beat; tapping the
                    // widget as a parent just opens the dashboard.
                    if model.profile?.role == .caregiver { model.wantsMeasure = true }
                }
        }
    }
}

/// App-side view model over the shared store. Everything the two dashboards
/// need, with the role deciding which half is reachable.
@MainActor
final class BeatModel: ObservableObject {
    @Published var readings: [BeatReading] = BeatStore.load()
    @Published var requests: [BeatRequest] = BeatStore.requests
    @Published var providers: [Provider] = BeatStore.providers
    @Published var wantsMeasure = false

    /// nil means onboarding has not picked a side yet.
    @Published var profile: Profile? {
        didSet {
            BeatStore.profile = profile
            guard let profile else { return }
            seedDayIfNeeded()
            if profile.role == .caregiver { seedFirstAskIfNeeded() }
        }
    }

    @Published var remindersOn: Bool {
        didSet {
            BeatStore.defaults.set(remindersOn, forKey: "beat.reminders")
            BeatNotifications.shared.setReminders(on: remindersOn, latest: readings.first)
        }
    }

    init() {
        remindersOn = BeatStore.defaults.bool(forKey: "beat.reminders")
        profile = BeatStore.profile
    }

    var role: Role? { profile?.role }

    // MARK: Onboarding

    func finishOnboarding(with profile: Profile, providers: [Provider]) {
        self.providers = providers
        BeatStore.providers = providers
        // Setting profile last so its didSet seeds against the final state.
        self.profile = profile
    }

    /// Keeps the same people and baby, flips which side of the app you see.
    func switchRole() {
        guard var next = profile else { return }
        let previousName = next.name
        next.role = next.role.other
        // The camera belongs to the caregiver side only.
        wantsMeasure = false

        switch next.role {
        case .parent:
            // The caregiver you just were becomes the provider you can ask.
            next.name = "mom"
            if providers.isEmpty {
                providers = [Provider(name: previousName, place: next.place)]
                BeatStore.providers = providers
            }
        case .caregiver:
            // You step into the shoes of the first provider on the list.
            next.name = providers.first?.name ?? "miss rosie"
            next.place = providers.first?.place ?? next.place
        }
        profile = next
    }

    // MARK: Readings (caregiver side)

    /// A caregiver counted a beat and sent it home. This also answers every
    /// ask that was waiting.
    func add(bpm: Int) {
        let reading = BeatReading(bpm: bpm,
                                  caregiver: profile?.name ?? "miss rosie",
                                  place: profile?.place ?? "little clouds daycare")
        BeatStore.add(reading)
        readings = BeatStore.load()
        answerWaitingRequests(at: reading.date)
        BeatNotifications.shared.notify(reading: reading)
        if remindersOn {
            BeatNotifications.shared.setReminders(on: true, latest: reading)
        }
    }

    private func answerWaitingRequests(at date: Date) {
        var all = BeatStore.requests
        for i in all.indices where all[i].isWaiting {
            all[i].answeredAt = date
        }
        BeatStore.requests = all
        requests = BeatStore.requests
    }

    // MARK: Requests (parent side)

    /// A parent asking a caregiver for a check. On a real pair of phones this
    /// lands on the caregiver's device; here both sides share one store, so
    /// the ask shows up the moment you switch to the caregiver view.
    func askForBeat(from provider: Provider) {
        guard let profile else { return }
        let request = BeatRequest(fromParent: profile.name, babyName: profile.babyName)
        var all = BeatStore.requests
        all.insert(request, at: 0)
        BeatStore.requests = all
        requests = BeatStore.requests
        BeatNotifications.shared.notifyRequest(request, to: provider.name)
    }

    func addProvider(name: String, place: String) {
        let provider = Provider(name: name, place: place)
        providers.append(provider)
        BeatStore.providers = providers
    }

    func removeProvider(_ provider: Provider) {
        providers.removeAll { $0.id == provider.id }
        BeatStore.providers = providers
    }

    /// True while a parent has an unanswered ask out.
    var hasWaitingRequest: Bool { requests.contains(where: \.isWaiting) }
    var waitingRequests: [BeatRequest] { requests.filter(\.isWaiting) }

    // MARK: Derived

    var latest: BeatReading? { readings.first }

    var todayReadings: [BeatReading] {
        readings.filter { Calendar.current.isDateInToday($0.date) }
    }

    var todayCount: Int { todayReadings.count }

    var averageBPM: Int? {
        let recent = readings.prefix(20)
        guard !recent.isEmpty else { return nil }
        return recent.map(\.bpm).reduce(0, +) / recent.count
    }

    // MARK: Seeding

    /// A believable day of checks, so whichever side you pick opens onto the
    /// story it is made for.
    private func seedDayIfNeeded() {
        guard !BeatStore.defaults.bool(forKey: "beat.seeded") else { return }
        BeatStore.defaults.set(true, forKey: "beat.seeded")

        let cal = Calendar.current
        let now = Date()
        let caregiver = profile?.role == .caregiver
            ? (profile?.name ?? "miss rosie")
            : (providers.first?.name ?? "miss rosie")
        let place = profile?.place ?? "little clouds daycare"
        let day: [(hour: Int, minute: Int, bpm: Int)] = [
            (8, 45, 138),   // drop off wiggles
            (10, 10, 126),  // after snack
            (12, 30, 96),   // nap time
            (15, 5, 152),   // big play
        ]
        let seeded = day.compactMap { slot -> BeatReading? in
            guard let date = cal.date(bySettingHour: slot.hour, minute: slot.minute,
                                      second: 0, of: now), date <= now else { return nil }
            return BeatReading(bpm: slot.bpm, date: date, caregiver: caregiver, place: place)
        }
        if seeded.isEmpty {
            // Opened before the daycare day starts: show yesterday's last check.
            BeatStore.save([BeatReading(bpm: 118, date: now.addingTimeInterval(-14 * 3600),
                                        caregiver: caregiver, place: place)])
        } else {
            BeatStore.save(seeded.reversed())
        }
        readings = BeatStore.load()
    }

    /// The caregiver view is only interesting with someone waiting on it.
    private func seedFirstAskIfNeeded() {
        guard !BeatStore.defaults.bool(forKey: "beat.seededAsk"),
              BeatStore.requests.isEmpty else { return }
        BeatStore.defaults.set(true, forKey: "beat.seededAsk")
        let ask = BeatRequest(date: Date().addingTimeInterval(-8 * 60),
                              fromParent: "mom",
                              babyName: profile?.babyName ?? "baby")
        BeatStore.requests = [ask]
        requests = BeatStore.requests
    }
}
