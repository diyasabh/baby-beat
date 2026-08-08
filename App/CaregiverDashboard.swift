import SwiftUI

/// The caregiver's half: see who is asking, count a beat, send it home.
/// This is the only side of the app that can take a reading.
struct CaregiverDashboard: View {
    @EnvironmentObject private var model: BeatModel
    @Binding var showsProfile: Bool

    private var babyName: String { model.profile?.babyName ?? "baby" }
    private var place: String { model.profile?.place ?? "daycare" }

    var body: some View {
        ZStack {
            CloudBackground()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    DashboardHeader(subtitle: "sending beats home from \(place)",
                                    symbol: "hands.sparkles.fill") {
                        showsProfile = true
                    }
                    if !model.waitingRequests.isEmpty { asksCard }
                    BeatHeroCard(reading: model.latest,
                                 caption: model.latest != nil ? "sent home to mom" : "",
                                 emptyTitle: "no beats sent yet",
                                 emptySubtitle: "take \(babyName)'s first check and it goes straight home")
                    statsRow
                    if model.readings.count > 1 { historyCard }
                    careCard
                    Spacer(minLength: 90)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }
        }
        .safeAreaInset(edge: .bottom) {
            HeartButton(title: model.waitingRequests.isEmpty ? "take a beat" : "take a beat for mom") {
                model.wantsMeasure = true
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 6)
        }
    }

    // MARK: Asks

    /// The whole reason a caregiver opens the app. Butter yellow so it reads
    /// as a warm nudge, never an alarm.
    private var asksCard: some View {
        CloudCard {
            VStack(alignment: .leading, spacing: 14) {
                Label("someone's asking", systemImage: "hand.wave.fill")
                    .font(Theme.body(16))
                    .foregroundStyle(Theme.ink)
                ForEach(model.waitingRequests) { ask in
                    PersonRow(name: "\(ask.fromParent) asked for a beat",
                              detail: relative(ask.date),
                              symbol: "envelope.fill",
                              tint: Theme.butter) {
                        SoftButton(title: "take it", systemImage: "heart.fill") {
                            model.wantsMeasure = true
                        }
                    }
                }
                Text("counting a beat answers everyone waiting.")
                    .font(Theme.meta(12))
                    .foregroundStyle(Theme.inkSoft)
            }
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private func relative(_ date: Date) -> String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .full
        return f.localizedString(for: date, relativeTo: .now)
    }

    // MARK: Cards

    private var statsRow: some View {
        HStack(spacing: 12) {
            StatChip(label: "sent today", value: "\(model.todayCount)")
            StatChip(label: "last sent", value: shortAgo(model.latest?.date))
            StatChip(label: "counting for", value: babyName)
        }
    }

    private var historyCard: some View {
        CloudCard {
            VStack(alignment: .leading, spacing: 12) {
                BrandLabel(title: "what you sent today", icon: .heartbeat)
                ForEach(model.todayReadings.prefix(5)) { r in
                    BeatRow(reading: r)
                }
                BeatSparkline(readings: model.readings)
                    .padding(.top, 4)
            }
        }
    }

    private var careCard: some View {
        CloudCard {
            VStack(alignment: .leading, spacing: 12) {
                BrandLabel(title: "taking a good beat", icon: .spark)
                InfoRow(word: "still", text: "rest their fingertip flat over the camera and flash", color: Theme.heart)
                InfoRow(word: "calm", text: "wait until they settle so the rhythm comes through clean", color: Theme.butter)
                InfoRow(word: "fifteen", text: "hold about fifteen seconds so the beats settle in", color: Color(red: 0.55, green: 0.66, blue: 0.93))
                Text("a beat is a hello, never a measurement or a verdict. if anything ever feels off, tell the parent and call for help.")
                    .font(Theme.meta(12))
                    .foregroundStyle(Theme.inkSoft)
                    .padding(.top, 2)
            }
        }
    }
}
