import SwiftUI

/// The parent's half: watch beats arrive, and ask a caregiver for one.
/// There is no way to take a beat from here on purpose.
struct ParentDashboard: View {
    @EnvironmentObject private var model: BeatModel
    @Binding var showsProfile: Bool

    private var babyName: String { model.profile?.babyName ?? "baby" }

    var body: some View {
        ZStack {
            CloudBackground()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    DashboardHeader(subtitle: "\(babyName)'s heartbeat, wherever you are",
                                    symbol: "figure.and.child.holdinghands") {
                        showsProfile = true
                    }
                    if model.hasWaitingRequest { waitingBanner }
                    BeatHeroCard(reading: model.latest,
                                 caption: model.latest.map { "by \($0.sender)" } ?? "",
                                 emptyTitle: "no beats from daycare yet",
                                 emptySubtitle: "checks will appear here the moment they are taken")
                    statsRow
                    if model.readings.count > 1 { historyCard }
                    providersCard
                    infoCard
                    remindersCard
                    Spacer(minLength: 90)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }
        }
        .safeAreaInset(edge: .bottom) {
            bottomAction
                .padding(.horizontal, 20)
                .padding(.bottom, 6)
        }
    }

    // MARK: Asking

    @ViewBuilder
    private var bottomAction: some View {
        if model.hasWaitingRequest {
            // Already asked: the button rests instead of letting you nag.
            HStack(spacing: 8) {
                Image(systemName: "hourglass")
                Text("waiting on a beat")
            }
            .font(Theme.body(18))
            .foregroundStyle(Theme.heart)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                Capsule()
                    .fill(Theme.cloud)
                    .shadow(color: Theme.skyTop.opacity(0.6), radius: 12, y: 8)
            )
        } else if let provider = model.providers.first {
            HeartButton(title: "ask \(provider.name) for a beat",
                        systemImage: "hand.wave.fill") {
                withAnimation(Theme.ease) { model.askForBeat(from: provider) }
            }
        } else {
            HeartButton(title: "add a caregiver", systemImage: "person.badge.plus") {
                showsProfile = true
            }
        }
    }

    private var waitingBanner: some View {
        CloudCard(padding: 16) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Theme.butter.opacity(0.35))
                        .frame(width: 40, height: 40)
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.ink)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("your ask is on its way")
                        .font(Theme.body(15))
                        .foregroundStyle(Theme.ink)
                    if let ask = model.waitingRequests.first {
                        (Text("asked ") + Text(ask.date, style: .relative) + Text(" ago"))
                            .font(Theme.meta(12))
                            .foregroundStyle(Theme.inkSoft)
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    // MARK: Cards

    private var statsRow: some View {
        HStack(spacing: 12) {
            StatChip(label: "checks today", value: "\(model.todayCount)")
            StatChip(label: "usual beat", value: model.averageBPM.map { "\($0)" } ?? "~")
            StatChip(label: "feeling", value: model.latest?.mood.word ?? "~")
        }
    }

    private var historyCard: some View {
        CloudCard {
            VStack(alignment: .leading, spacing: 12) {
                BrandLabel(title: "today at daycare", icon: .sun, tint: Theme.butter)
                ForEach(model.todayReadings.prefix(5)) { r in
                    BeatRow(reading: r)
                }
                BeatSparkline(readings: model.readings)
                    .padding(.top, 4)
            }
        }
    }

    private var providersCard: some View {
        CloudCard {
            VStack(alignment: .leading, spacing: 14) {
                Label("your people", systemImage: "person.2.fill")
                    .font(Theme.body(16))
                    .foregroundStyle(Theme.ink)
                if model.providers.isEmpty {
                    Text("add whoever looks after \(babyName), then you can ask them for a beat any time.")
                        .font(Theme.meta(13))
                        .foregroundStyle(Theme.inkSoft)
                } else {
                    ForEach(model.providers) { provider in
                        PersonRow(name: provider.name, detail: provider.place) {
                            if model.hasWaitingRequest {
                                Text("asked")
                                    .font(Theme.meta(12))
                                    .foregroundStyle(Theme.inkSoft)
                            } else {
                                SoftButton(title: "ask", systemImage: "hand.wave.fill") {
                                    withAnimation(Theme.ease) { model.askForBeat(from: provider) }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var infoCard: some View {
        CloudCard {
            VStack(alignment: .leading, spacing: 12) {
                BrandLabel(title: "what's a happy beat", icon: .spark)
                InfoRow(word: "sleepy", text: "fast asleep, around 90 to 120", color: BeatMood.sleepy.color)
                InfoRow(word: "cozy", text: "calm and cuddly, around 100 to 160", color: BeatMood.cozy.color)
                InfoRow(word: "bouncy", text: "wiggly and playing, up to about 180", color: BeatMood.bouncy.color)
                InfoRow(word: "worrying", text: "under 75 or over 185 turns everything red so you can check right away", color: Theme.alert)
                Text("a good beat never buzzes your pocket. it just lands on your widget, there whenever you want to look. only a worrying one sends a note.")
                    .font(Theme.meta(12))
                    .foregroundStyle(Theme.inkSoft)
                    .padding(.top, 2)
                Text("made for sweet peace of mind, not a medical device. if anything ever feels off, call your pediatrician.")
                    .font(Theme.meta(12))
                    .foregroundStyle(Theme.inkSoft)
                    .padding(.top, 2)
            }
        }
    }

    private var remindersCard: some View {
        CloudCard {
            Toggle(isOn: $model.remindersOn) {
                VStack(alignment: .leading, spacing: 4) {
                    BrandLabel(title: "nudge me if it goes quiet", icon: .bell)
                    Text("a worrying beat always sends a note. turn this on and we'll also whisper if a whole stretch of the day goes by with no check at all.")
                        .font(Theme.meta(13))
                        .foregroundStyle(Theme.inkSoft)
                }
            }
            .tint(Theme.heart)
        }
    }
}

/// One line of the day's history. Shared by both dashboards.
struct BeatRow: View {
    var reading: BeatReading

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(reading.mood.color)
                .frame(width: 8, height: 8)
            Text(reading.date, format: .dateTime.hour().minute())
                .font(Theme.meta(13))
                .foregroundStyle(Theme.inkSoft)
                .frame(width: 70, alignment: .leading)
            Text("\(reading.bpm) bpm")
                .font(Theme.body(14))
                .foregroundStyle(Theme.ink)
            Spacer()
            Text(reading.mood.word)
                .font(Theme.meta(13))
                .foregroundStyle(Theme.inkSoft)
        }
    }
}

/// A colored dot, a word, and its meaning.
struct InfoRow: View {
    var word: String
    var text: String
    var color: Color

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
                .padding(.top, 4)
            Text(word)
                .font(Theme.body(14))
                .foregroundStyle(Theme.ink)
                .frame(width: 68, alignment: .leading)
            Text(text)
                .font(Theme.meta(13))
                .foregroundStyle(Theme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
