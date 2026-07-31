import SwiftUI
import AVFoundation

/// The capture flow: rest a fingertip on the rear camera, the flash glows,
/// and we count the little beats.
struct MeasureView: View {
    @EnvironmentObject private var model: BeatModel
    @Environment(\.dismiss) private var dismiss
    @StateObject private var reader = PulseCameraReader()

    private enum Stage { case intro, reading, done(Int) }
    @State private var stage: Stage = .intro

    var body: some View {
        ZStack {
            CloudBackground()
            VStack(spacing: 20) {
                topBar
                Spacer(minLength: 0)
                switch stage {
                case .intro: introCard
                case .reading: readingCard
                case .done(let bpm): doneCard(bpm: bpm)
                }
                Spacer(minLength: 0)
            }
            .padding(20)
        }
        .onDisappear { reader.stop() }
        .onChange(of: reader.progress) { _, progress in
            // The rolling window trims itself to just under windowSeconds,
            // so progress settles at ~0.99 rather than touching 1 exactly.
            if case .reading = stage, progress >= 0.98, let bpm = reader.bpm {
                reader.stop()
                withAnimation(Theme.ease) { stage = .done(bpm) }
            }
        }
    }

    private var topBar: some View {
        HStack {
            Button {
                reader.stop()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .padding(12)
                    .background(Circle().fill(Theme.cloud).shadow(color: Theme.skyTop.opacity(0.5), radius: 8, y: 4))
            }
            .buttonStyle(SquishButtonStyle())
            Spacer()
            Text("daycare check in")
                .font(Theme.body(16))
                .foregroundStyle(Theme.ink)
            Spacer()
            Color.clear.frame(width: 41, height: 41)
        }
    }

    // MARK: Stages

    private var introCard: some View {
        CloudCard(padding: 24) {
            VStack(spacing: 16) {
                PulsingHeart(bpm: 120, size: 96)
                Text("let's count the little beats")
                    .font(Theme.title(22))
                    .foregroundStyle(Theme.ink)
                VStack(alignment: .leading, spacing: 10) {
                    stepRow(icon: "hand.point.up.left.fill", text: "rest baby's fingertip flat on the back camera")
                    stepRow(icon: "flashlight.on.fill", text: "the flash turns on like a tiny nightlight")
                    stepRow(icon: "moon.zzz.fill", text: "hold soft and still for about fifteen seconds")
                }
                HeartButton(title: "start counting") {
                    beginReading()
                }
                .padding(.top, 4)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var readingCard: some View {
        CloudCard(padding: 24) {
            VStack(spacing: 18) {
                PulsingHeart(bpm: reader.bpm ?? 118, size: 104)
                if let bpm = reader.bpm {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("\(bpm)")
                            .font(Theme.number(44))
                            .foregroundStyle(Theme.ink)
                            .contentTransition(.numericText())
                        Text("so far")
                            .font(Theme.meta(13))
                            .foregroundStyle(Theme.inkSoft)
                    }
                }
                LiveWave(samples: reader.samples)
                    .frame(height: 56)
                ProgressView(value: reader.progress)
                    .tint(Theme.heart)
                Text(reader.isFingerDetected ? "there it is, hold soft and still" : "looking for a fingertip on the camera...")
                    .font(Theme.meta(14))
                    .foregroundStyle(Theme.inkSoft)
                    .animation(Theme.ease, value: reader.isFingerDetected)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func doneCard(bpm: Int) -> some View {
        let mood = BeatMood(bpm: bpm)
        return CloudCard(padding: 24) {
            VStack(spacing: 14) {
                PulsingHeart(bpm: bpm, size: 104)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(bpm)")
                        .font(Theme.number(58))
                        .foregroundStyle(Theme.ink)
                    Text("beats a minute")
                        .font(Theme.meta(14))
                        .foregroundStyle(Theme.inkSoft)
                }
                MoodPill(mood: mood)
                Text(mood.reassurance)
                    .font(Theme.body(15))
                    .foregroundStyle(Theme.ink)
                HeartButton(title: sendTitle, systemImage: "paperplane.fill") {
                    model.add(bpm: bpm)
                    dismiss()
                }
                Button("try again") {
                    beginReading()
                }
                .font(Theme.meta(14))
                .foregroundStyle(Theme.inkSoft)
                .buttonStyle(SquishButtonStyle())
            }
            .frame(maxWidth: .infinity)
        }
    }

    /// Names the parent when someone is actually waiting on this beat.
    private var sendTitle: String {
        if let ask = model.waitingRequests.first { return "send it to \(ask.fromParent)" }
        return "send it home"
    }

    private func stepRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundStyle(Theme.heart)
                .frame(width: 24)
            Text(text)
                .font(Theme.meta(14))
                .foregroundStyle(Theme.ink)
        }
    }

    private func beginReading() {
        #if targetEnvironment(simulator)
        withAnimation(Theme.ease) { stage = .reading }
        reader.start()
        #else
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async {
                guard granted else { return }
                withAnimation(Theme.ease) { stage = .reading }
                reader.start()
            }
        }
        #endif
    }
}

/// The live shimmer of the fingertip signal.
struct LiveWave: View {
    var samples: [Double]

    var body: some View {
        GeometryReader { geo in
            Path { p in
                guard samples.count > 1 else { return }
                let w = geo.size.width
                let h = geo.size.height
                let stepX = w / CGFloat(samples.count - 1)
                p.move(to: CGPoint(x: 0, y: h * (1 - samples[0])))
                for (i, s) in samples.enumerated().dropFirst() {
                    p.addLine(to: CGPoint(x: CGFloat(i) * stepX, y: h * (1 - s)))
                }
            }
            .stroke(
                LinearGradient(colors: [Theme.heart, Theme.heartDeep],
                               startPoint: .leading, endPoint: .trailing),
                style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
            )
        }
        .opacity(samples.isEmpty ? 0.25 : 1)
        .animation(Theme.ease, value: samples.isEmpty)
    }
}
