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
    @State private var beatPop = false

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
                LensGuide()
                Text("let's count the little beats")
                    .font(Theme.title(22))
                    .foregroundStyle(Theme.ink)
                VStack(alignment: .leading, spacing: 10) {
                    stepRow(icon: "hand.point.up.left.fill", text: "rest a fingertip flat on the heart lens, top left of the camera bump")
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
                if reader.isFingerDetected {
                    PulsingHeart(bpm: reader.bpm ?? 118, size: 104)
                        .scaleEffect(beatPop ? 1.07 : 1)
                } else {
                    LensGuide()
                }
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
                if reader.isFingerDetected {
                    LiveWave(samples: reader.samples)
                        .frame(height: 56)
                } else {
                    WarmthMeter(warmth: reader.warmth)
                        .padding(.horizontal, 8)
                }
                ProgressView(value: reader.progress)
                    .tint(Theme.heart)
                Text(guidance)
                    .font(Theme.meta(14))
                    .foregroundStyle(Theme.inkSoft)
                    .animation(Theme.ease, value: guidance)
            }
            .frame(maxWidth: .infinity)
            .animation(Theme.ease, value: reader.isFingerDetected)
        }
        // Each landed beat: a soft tap in the hand and a pop of the heart,
        // so a good signal is something the parent can feel.
        .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.8), trigger: reader.beatTick)
        .onChange(of: reader.beatTick) { _, _ in
            var still = Transaction()
            still.disablesAnimations = true
            withTransaction(still) { beatPop = true }
            withAnimation(.spring(response: 0.24, dampingFraction: 0.5)) { beatPop = false }
        }
    }

    /// Hot-and-cold coaching while the fingertip hunts for the heart lens.
    private var guidance: String {
        if reader.isFingerDetected { return "there it is, hold soft and still" }
        if reader.warmth > 0.6 { return "so close, a tiny slide more" }
        if reader.warmth > 0.2 { return "getting warmer, keep sliding slowly" }
        return "cover the heart lens, then slide slowly until this fills"
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

/// A tiny map of the camera bump with the counting lens marked by a heart.
/// The app only ever reads the main 1x camera; on iPhones with several
/// rear lenses that is the top-left one in the cluster.
struct LensGuide: View {
    @State private var breathe = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Theme.ink.opacity(0.92))
                .frame(width: 148, height: 100)
            Circle()
                .fill(Theme.butter)
                .frame(width: 10, height: 10)
                .offset(x: 52, y: -26)
            lens(offset: CGSize(width: -38, height: -24), isTarget: true)
            lens(offset: CGSize(width: -38, height: 24), isTarget: false)
            lens(offset: CGSize(width: 12, height: 0), isTarget: false)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                breathe = true
            }
        }
    }

    private func lens(offset: CGSize, isTarget: Bool) -> some View {
        ZStack {
            Circle()
                .fill(.black.opacity(0.55))
                .overlay(Circle().stroke(.white.opacity(0.25), lineWidth: 1.5))
                .frame(width: 34, height: 34)
            if isTarget {
                Circle()
                    .stroke(Theme.heart, lineWidth: 3)
                    .frame(width: 44, height: 44)
                    .scaleEffect(breathe ? 1.08 : 0.94)
                    .opacity(breathe ? 0.65 : 1)
                Image(systemName: "heart.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.heart)
            }
        }
        .offset(offset)
    }
}

/// Fills as the sliding fingertip gets closer to the counting lens.
struct WarmthMeter: View {
    var warmth: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.skyTop.opacity(0.5))
                Capsule()
                    .fill(LinearGradient(colors: [Theme.butter, Theme.heart],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(12, geo.size.width * warmth))
            }
        }
        .frame(height: 12)
        .animation(Theme.ease, value: warmth)
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
