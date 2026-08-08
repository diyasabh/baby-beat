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
            StatChip(label: "last check", value: shortAgo(model.latest?.date))
            StatChip(label: "from", value: model.latest?.place ?? "~")
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
                BrandLabel(title: "what a beat is here", icon: .spark)
                InfoRow(word: "felt", text: "a fingertip rests on the camera and the phone feels the rhythm of little beats", color: Theme.heart)
                InfoRow(word: "shared", text: "each check flies home to you the moment it is taken", color: Theme.butter)
                InfoRow(word: "honest", text: "no numbers and no scores for now — a beat is a hello, not a reading", color: Color(red: 0.55, green: 0.66, blue: 0.93))
                Text("baby beat is a way to feel close, not a medical device. it never measures or judges baby's health. if anything ever feels off, trust yourself and call your pediatrician.")
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
                    Text("every check sends a soft note when it lands. turn this on and we'll also whisper if a whole stretch of the day goes by with no check at all.")
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
            Image(systemName: "heart.fill")
                .font(.system(size: 10))
                .foregroundStyle(Theme.heart)
            Text(reading.date, format: .dateTime.hour().minute())
                .font(Theme.meta(13))
                .foregroundStyle(Theme.inkSoft)
                .frame(width: 70, alignment: .leading)
            Text("a little beat")
                .font(Theme.body(14))
                .foregroundStyle(Theme.ink)
            Spacer()
            Text("by \(reading.sender)")
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
