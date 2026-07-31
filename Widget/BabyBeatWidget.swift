import WidgetKit
import SwiftUI

@main
struct BabyBeatWidgetBundle: WidgetBundle {
    var body: some Widget {
        BabyBeatWidget()
    }
}

struct BeatEntry: TimelineEntry {
    let date: Date
    let reading: BeatReading?
    /// Alternates each minute; iOS animates the change so the heart
    /// takes a soft breath between entries.
    let pulsePhase: Bool
    /// Which side of the app owns this phone.
    var role: Role = .parent
    /// Caregiver only: the oldest parent still waiting on a beat.
    var waitingAsk: BeatRequest?
}

struct BeatProvider: TimelineProvider {
    func placeholder(in context: Context) -> BeatEntry {
        BeatEntry(date: .now, reading: BeatReading(bpm: 128), pulsePhase: false)
    }

    func getSnapshot(in context: Context, completion: @escaping (BeatEntry) -> Void) {
        completion(entry(at: .now, pulsePhase: false,
                         reading: BeatStore.latest ?? BeatReading(bpm: 128)))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BeatEntry>) -> Void) {
        let reading = BeatStore.latest
        // One entry per minute for the next hour, alternating the pulse pose.
        let now = Date()
        let entries = (0..<60).map { minute in
            entry(at: now.addingTimeInterval(Double(minute) * 60),
                  pulsePhase: minute % 2 == 1,
                  reading: reading)
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }

    private func entry(at date: Date, pulsePhase: Bool, reading: BeatReading?) -> BeatEntry {
        let role = BeatStore.role ?? .parent
        return BeatEntry(date: date, reading: reading, pulsePhase: pulsePhase,
                         role: role,
                         waitingAsk: role == .caregiver ? BeatStore.waitingRequests.last : nil)
    }
}

struct BabyBeatWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "BabyBeatWidget", provider: BeatProvider()) { entry in
            BeatWidgetView(entry: entry)
                .widgetURL(URL(string: "babybeat://check"))
        }
        .configurationDisplayName("Baby Beat")
        .description("Baby's latest heartbeat from daycare, always close.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular])
    }
}

struct BeatWidgetView: View {
    var entry: BeatEntry
    @Environment(\.widgetFamily) private var family

    /// A worrying beat flips the widget's whole temperature: alert sky,
    /// white heart, white ink. Same primitives, different weather.
    private var worrying: Bool { entry.reading?.mood.isWorrying == true }
    /// A caregiver with a parent waiting sees the ask instead of the beat,
    /// unless the last reading was worrying, which outranks everything.
    private var asking: BeatRequest? { worrying ? nil : entry.waitingAsk }
    private var ink: Color { worrying ? .white : Theme.ink }
    private var inkSoft: Color { worrying ? .white.opacity(0.75) : Theme.inkSoft }
    private var heartTint: Color { worrying ? .white : Theme.heart }
    private var heartTintDeep: Color { worrying ? Color(white: 0.88) : Theme.heartDeep }

    /// Small line above the number: where it came from, or where it went.
    private var captionLine: String {
        guard let reading = entry.reading else { return "baby beat" }
        return entry.role == .caregiver ? "sent home" : "from \(reading.place)"
    }

    private var emptyTitle: String {
        entry.role == .caregiver ? "no beats sent yet" : "no beats from daycare yet"
    }

    var body: some View {
        Group {
            switch family {
            case .accessoryCircular: circularView
            case .accessoryRectangular: rectangularView
            case .systemMedium: mediumView
            default: smallView
            }
        }
        .containerBackground(for: .widget) {
            if family == .systemSmall || family == .systemMedium {
                skyBackground
            } else {
                Color.clear
            }
        }
    }

    // MARK: Home screen

    @ViewBuilder
    private var smallView: some View {
        if let ask = asking {
            VStack(spacing: 6) {
                PulsingHeart(bpm: 108, size: 56, animated: false,
                             phase: entry.pulsePhase)
                Text("\(ask.fromParent) is asking")
                    .font(Theme.body(14))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)
                Text("tap to take a beat")
                    .font(Theme.meta(11))
                    .foregroundStyle(Theme.inkSoft)
            }
        } else {
            beatSmallView
        }
    }

    private var beatSmallView: some View {
        VStack(spacing: 6) {
            PulsingHeart(bpm: entry.reading?.bpm ?? 120, size: 64,
                         animated: false, phase: entry.pulsePhase,
                         tint: heartTint, tintDeep: heartTintDeep)
            if let reading = entry.reading {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text("\(reading.bpm)")
                        .font(Theme.number(30))
                        .foregroundStyle(ink)
                    Text("bpm")
                        .font(Theme.meta(11))
                        .foregroundStyle(inkSoft)
                }
                if worrying {
                    Text("check on baby")
                        .font(Theme.meta(11))
                        .foregroundStyle(ink)
                }
                checkedLine
            } else {
                Text("no beats yet")
                    .font(Theme.meta(12))
                    .foregroundStyle(inkSoft)
            }
        }
    }

    @ViewBuilder
    private var mediumView: some View {
        if let ask = asking {
            HStack(spacing: 16) {
                PulsingHeart(bpm: 108, size: 72, animated: false, phase: entry.pulsePhase)
                VStack(alignment: .leading, spacing: 5) {
                    Text("someone's asking")
                        .font(Theme.meta(12))
                        .foregroundStyle(Theme.inkSoft)
                    Text("\(ask.fromParent) asked for a beat")
                        .font(Theme.title(18))
                        .foregroundStyle(Theme.ink)
                    (Text("asked ") + Text(ask.date, style: .relative) + Text(" ago"))
                        .font(Theme.meta(11))
                        .foregroundStyle(Theme.inkSoft)
                    Text("tap to take one for \(ask.babyName)")
                        .font(Theme.meta(12))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Theme.heart))
                        .padding(.top, 2)
                }
                Spacer(minLength: 0)
            }
        } else {
            beatMediumView
        }
    }

    private var beatMediumView: some View {
        HStack(spacing: 16) {
            PulsingHeart(bpm: entry.reading?.bpm ?? 120, size: 84,
                         animated: false, phase: entry.pulsePhase,
                         tint: heartTint, tintDeep: heartTintDeep)
            VStack(alignment: .leading, spacing: 5) {
                Text(captionLine)
                    .font(Theme.meta(12))
                    .foregroundStyle(inkSoft)
                if let reading = entry.reading {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(reading.bpm)")
                            .font(Theme.number(38))
                            .foregroundStyle(ink)
                        Text("beats a minute")
                            .font(Theme.meta(12))
                            .foregroundStyle(inkSoft)
                    }
                    Text(worrying ? "\(reading.mood.phrase), check on baby" : reading.mood.phrase)
                        .font(Theme.meta(12))
                        .foregroundStyle(worrying ? Theme.alert : .white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(worrying ? .white : reading.mood.color))
                    checkedLine
                } else {
                    Text(emptyTitle)
                        .font(Theme.body(15))
                        .foregroundStyle(ink)
                    Text(entry.role == .caregiver
                         ? "tap to count the first one"
                         : "checks appear the moment they are taken")
                        .font(Theme.meta(12))
                        .foregroundStyle(inkSoft)
                }
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: Lock screen

    @ViewBuilder
    private var circularView: some View {
        if asking != nil {
            VStack(spacing: 0) {
                Image(systemName: "hand.wave.fill")
                    .font(.system(size: 14))
                Text("ask")
                    .font(Theme.title(15))
            }
        } else {
            VStack(spacing: 0) {
                Image(systemName: worrying ? "exclamationmark.heart.fill" : "heart.fill")
                    .font(.system(size: 14))
                Text(entry.reading.map { "\($0.bpm)" } ?? "~")
                    .font(Theme.title(18))
            }
        }
    }

    @ViewBuilder
    private var rectangularView: some View {
        if let ask = asking {
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Image(systemName: "hand.wave.fill")
                        .font(.system(size: 11))
                    Text("baby beat")
                        .font(Theme.body(12))
                }
                Text("\(ask.fromParent) asked for a beat")
                    .font(Theme.title(15))
                Text(ask.date, style: .relative)
                    .font(Theme.meta(11))
                    .opacity(0.7)
            }
        } else {
            beatRectangularView
        }
    }

    private var beatRectangularView: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 4) {
                if worrying {
                    Image(systemName: "exclamationmark.heart.fill")
                        .font(.system(size: 11))
                } else {
                    BrandIcon(icon: .heartbeat, size: 13)
                }
                Text("baby beat")
                    .font(Theme.body(12))
            }
            if let reading = entry.reading {
                Text(worrying ? "\(reading.bpm) bpm, check baby" : "\(reading.bpm) bpm, \(reading.mood.word)")
                    .font(Theme.title(15))
                Text(reading.date, style: .relative)
                    .font(Theme.meta(11))
                    .opacity(0.7)
            } else {
                Text("no beats yet")
                    .font(Theme.title(14))
            }
        }
    }

    // MARK: Bits

    /// Live "checked n ago" line that keeps itself current.
    @ViewBuilder
    private var checkedLine: some View {
        if let reading = entry.reading {
            (Text("checked ") + Text(reading.date, style: .relative) + Text(" ago"))
                .font(Theme.meta(10))
                .foregroundStyle(inkSoft)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }

    /// The same sky as the app, with one thick puff in the corner.
    /// A worrying beat turns the whole sky alert red.
    private var skyBackground: some View {
        ZStack {
            if worrying || asking != nil {
                // Alert and asking get their own weather, so they stay
                // unmistakable against the everyday drawn sky.
                LinearGradient(colors: skyColors, startPoint: .top, endPoint: .bottom)
                CloudShape()
                    .fill(.white.opacity(worrying ? 0.18 : 0.55))
                    .frame(width: 110, height: 60)
                    .offset(x: 50, y: -52)
            } else {
                Image("sky-bg")
                    .resizable()
                    .scaledToFill()
            }
        }
    }

    /// Three weathers: alert red, a warm butter sky when someone is asking,
    /// and the everyday baby blue.
    private var skyColors: [Color] {
        if worrying { return [Theme.alert, Theme.alertDeep] }
        if asking != nil { return [Theme.butter, Theme.skyBottom] }
        return [Theme.skyTop, Theme.skyBottom]
    }
}
