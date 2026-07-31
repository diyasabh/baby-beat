import SwiftUI

/// The one card of the app: cloud white, big soft corners, a gentle blue
/// shadow like it is resting on the sky. Every panel uses this.
struct CloudCard<Content: View>: View {
    var padding: CGFloat = 20
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                    .fill(Theme.cloud)
                    .shadow(color: Theme.skyTop.opacity(0.6), radius: 16, y: 10)
            )
    }
}

/// Small labeled stat used in the dashboard row.
struct StatChip: View {
    var label: String
    var value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(Theme.body(20))
                .foregroundStyle(Theme.ink)
            Text(label)
                .font(Theme.meta(12))
                .foregroundStyle(Theme.inkSoft)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Theme.cloud)
                .shadow(color: Theme.skyTop.opacity(0.5), radius: 12, y: 8)
        )
    }
}

/// Little rounded pill for a mood word.
struct MoodPill: View {
    var mood: BeatMood

    var body: some View {
        Text(mood.phrase)
            .font(Theme.meta(13))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Capsule().fill(mood.color))
    }
}

/// The big pink action button. One style for every primary action.
struct HeartButton: View {
    var title: String
    var systemImage: String = "heart.fill"
    /// When set, a hand-drawn mark is used instead of the SF Symbol.
    var brand: Brand?
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let brand {
                    BrandIcon(icon: brand, size: 20)
                } else {
                    Image(systemName: systemImage)
                }
                Text(title)
            }
            .font(Theme.body(18))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                Capsule().fill(
                    LinearGradient(colors: [Theme.heart, Theme.heartDeep],
                                   startPoint: .top, endPoint: .bottom)
                )
                .shadow(color: Theme.heartDeep.opacity(0.4), radius: 12, y: 8)
            )
        }
        .buttonStyle(SquishButtonStyle())
    }
}

/// The shared press feel: a soft squish, like poking a cheek.
struct SquishButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(Theme.ease, value: configuration.isPressed)
    }
}

/// The big beat card at the top of both dashboards. Same heart, same numbers,
/// same alert temperature; only the caption differs by who is looking.
struct BeatHeroCard: View {
    var reading: BeatReading?
    /// Line under the timestamp: who sent it, or who it went to.
    var caption: String
    var emptyTitle: String
    var emptySubtitle: String

    var body: some View {
        CloudCard {
            if let reading {
                let worrying = reading.mood.isWorrying
                VStack(spacing: 10) {
                    PulsingHeart(bpm: reading.bpm, size: 108,
                                 tint: worrying ? Theme.alert : Theme.heart,
                                 tintDeep: worrying ? Theme.alertDeep : Theme.heartDeep)
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("\(reading.bpm)")
                            .font(Theme.number(58))
                            .foregroundStyle(worrying ? Theme.alert : Theme.ink)
                        Text("beats a minute")
                            .font(Theme.meta(14))
                            .foregroundStyle(Theme.inkSoft)
                    }
                    Text(reading.mood.reassurance)
                        .font(Theme.body(16))
                        .foregroundStyle(worrying ? Theme.alert : Theme.ink)
                    MoodPill(mood: reading.mood)
                    VStack(spacing: 2) {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.system(size: 11))
                            Text("checked ") + Text(reading.date, style: .relative) + Text(" ago")
                        }
                        Text(caption)
                    }
                    .font(Theme.meta(13))
                    .foregroundStyle(Theme.inkSoft)
                }
                .frame(maxWidth: .infinity)
            } else {
                VStack(spacing: 12) {
                    PulsingHeart(bpm: 120, size: 108)
                    Text(emptyTitle)
                        .font(Theme.body(18))
                        .foregroundStyle(Theme.ink)
                    Text(emptySubtitle)
                        .font(Theme.meta(14))
                        .foregroundStyle(Theme.inkSoft)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

/// A labeled text field in the house style. Used across onboarding and
/// anywhere else a grown-up types a name.
struct SoftField: View {
    var label: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(Theme.meta(12))
                .foregroundStyle(Theme.inkSoft)
            TextField("", text: $text)
                .font(Theme.body(16))
                .foregroundStyle(Theme.ink)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Theme.skyBottom.opacity(0.7))
                )
        }
    }
}

/// The top of both dashboards: the app mark, a role-specific line, and the
/// little face that opens settings. One header, two sets of words.
struct DashboardHeader: View {
    var subtitle: String
    var symbol: String
    var onTapProfile: () -> Void

    var body: some View {
        ZStack {
            VStack(spacing: 4) {
                HStack(spacing: 8) {
                    BrandIcon(icon: .heartbeat, size: 24)
                        .foregroundStyle(Theme.heart)
                    Text("baby beat")
                        .font(Theme.title(30))
                        .foregroundStyle(Theme.ink)
                }
                Text(subtitle)
                    .font(Theme.meta(14))
                    .foregroundStyle(Theme.inkSoft)
            }
            .frame(maxWidth: .infinity)

            HStack {
                Spacer()
                Button(action: onTapProfile) {
                    Image(systemName: symbol)
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.heart)
                        .frame(width: 40, height: 40)
                        .background(
                            Circle()
                                .fill(Theme.cloud)
                                .shadow(color: Theme.skyTop.opacity(0.5), radius: 8, y: 4)
                        )
                }
                .buttonStyle(SquishButtonStyle())
            }
        }
        .padding(.top, 6)
    }
}

/// One grown-up in a list: a soft circle, their name and place, and whatever
/// action belongs on the right. Providers and asks both use this.
struct PersonRow<Trailing: View>: View {
    var name: String
    var detail: String
    var symbol: String = "person.fill"
    var tint: Color = Theme.heart
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: symbol)
                    .font(.system(size: 16))
                    .foregroundStyle(tint)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(Theme.body(15))
                    .foregroundStyle(Theme.ink)
                Text(detail)
                    .font(Theme.meta(12))
                    .foregroundStyle(Theme.inkSoft)
            }
            Spacer(minLength: 8)
            trailing
        }
    }
}

/// The quieter sibling of HeartButton, for secondary actions like "ask".
struct SoftButton: View {
    var title: String
    var systemImage: String
    var tint: Color = Theme.heart
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                Text(title)
            }
            .font(Theme.meta(13))
            .foregroundStyle(tint)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Capsule().fill(tint.opacity(0.13)))
        }
        .buttonStyle(SquishButtonStyle())
    }
}

/// Mini history: one capsule per reading, height follows bpm, color follows mood.
struct BeatSparkline: View {
    var readings: [BeatReading]

    var body: some View {
        let recent = Array(readings.prefix(12).reversed())
        HStack(alignment: .bottom, spacing: 6) {
            ForEach(recent) { r in
                VStack(spacing: 4) {
                    Capsule()
                        .fill(r.mood.color.opacity(0.85))
                        .frame(width: 14, height: barHeight(bpm: r.bpm))
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 64, alignment: .bottom)
    }

    private func barHeight(bpm: Int) -> CGFloat {
        let clamped = min(max(bpm, 70), 190)
        return CGFloat(clamped - 60) / 130 * 64
    }
}
