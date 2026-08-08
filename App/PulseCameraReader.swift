import AVFoundation
import Combine
import UIKit

/// Reads a heartbeat from the rear camera with the flash on, using
/// photoplethysmography: a fingertip rests on the lens, the torch lights it
/// like a tiny nightlight, and every pulse of blood shifts the light the
/// camera sees. We track that shimmer and count the beats.
///
/// Accuracy is fought for in layers:
///  - the GREEN channel carries the pulse (red saturates under the torch)
///  - only the center of the frame is averaged, edges leak ambient light
///  - the frame rate is pinned to 30fps so sample spacing stays honest
///  - a ~1s moving average is subtracted (detrending), so breathing and
///    pressure drift can't swallow the beats
///  - peaks are found against an adaptive threshold, not a fixed one
///  - the beat rate is the MEDIAN interval, after dropping gaps that look
///    like missed beats (~2x) or double-counts (~0.5x)
///  - a reading is only trusted when enough beats agree with each other;
///    otherwise `isConfident` stays false and no result should be kept
///
/// On the simulator there is no camera, so a synthetic fingertip signal is
/// fed through the exact same pipeline.
final class PulseCameraReader: NSObject, ObservableObject {
    @Published var bpm: Int?
    @Published var isFingerDetected = false
    @Published var samples: [Double] = []   // recent normalized signal for the live wave
    @Published var progress: Double = 0      // 0...1 over the measurement window
    /// 0...1 hot-and-cold signal for finding the right lens on phones with
    /// several. Only one lens is ever sampled (the main wide camera); this
    /// rises as a sliding fingertip gets closer to it.
    @Published var warmth: Double = 0
    /// Increments the moment each beat lands, so the UI can tap and pop in
    /// time with the pulse.
    @Published var beatTick = 0
    /// True only when the detected beats agree with each other well enough
    /// to trust. A reading should never be kept without it.
    @Published var isConfident = false

    private let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "babybeat.camera")
    private var device: AVCaptureDevice?

    private var greenWindow: [Double] = []
    private var timestamps: [Double] = []
    private let windowSeconds: Double = 15
    /// Beats must land at least this far apart (~214 bpm ceiling).
    private let refractory: Double = 0.28

    func start() {
        resetSignal()
        #if targetEnvironment(simulator)
        queue.async { [weak self] in self?.startSynthetic() }
        #else
        queue.async { [weak self] in self?.configureAndRun() }
        #endif
    }

    func stop() {
        queue.async { [weak self] in
            guard let self else { return }
            self.syntheticTimer?.cancel()
            self.syntheticTimer = nil
            if self.session.isRunning { self.session.stopRunning() }
            if let d = self.device, d.hasTorch {
                try? d.lockForConfiguration()
                d.torchMode = .off
                d.unlockForConfiguration()
            }
        }
    }

    /// Every reading starts from silence: stale samples from a previous
    /// attempt must never leak into a new count.
    private func resetSignal() {
        queue.async { [weak self] in
            guard let self else { return }
            self.greenWindow = []
            self.timestamps = []
            self.fingerLatched = false
            self.fingerSince = nil
            self.exposureLocked = false
            self.warmthSmoothed = 0
            self.lastBeatAt = -1
        }
        bpm = nil
        isConfident = false
        progress = 0
        samples = []
    }

    // MARK: Real capture

    private func configureAndRun() {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device) else { return }
        self.device = device

        session.beginConfiguration()
        session.sessionPreset = .low
        if session.canAddInput(input) { session.addInput(input) }

        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        output.setSampleBufferDelegate(self, queue: queue)
        if session.canAddOutput(output) { session.addOutput(output) }
        session.commitConfiguration()

        try? device.lockForConfiguration()
        // Pin the frame rate: auto-exposure may otherwise slow the sensor
        // and stretch the sample spacing mid-reading.
        device.activeVideoMinFrameDuration = CMTime(value: 1, timescale: 30)
        device.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: 30)
        if device.hasTorch { try? device.setTorchModeOn(level: 1.0) }
        device.unlockForConfiguration()

        session.startRunning()
    }

    // MARK: Synthetic capture (simulator only)

    private var syntheticTimer: DispatchSourceTimer?
    private var syntheticStart: Double = 0
    private var syntheticTargetBPM: Double = Double(Int.random(in: 112...146))

    private func startSynthetic() {
        syntheticStart = CACurrentMediaTime()
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now(), repeating: 1.0 / 30.0)
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            let t = CACurrentMediaTime() - self.syntheticStart
            // No fingertip for the first moments, so the searching state shows.
            guard t > 1.6 else {
                self.process(green: 20, brightness: 0.05, redRatio: 0.3, at: t)
                return
            }
            // A believable pulse: main beat, a soft dicrotic bump, slow drift, noise.
            let hz = self.syntheticTargetBPM / 60.0
            let beat = sin(2 * .pi * hz * t)
            let bump = 0.3 * sin(4 * .pi * hz * t + 0.8)
            let drift = 6.0 * sin(0.1 * t)
            let noise = Double.random(in: -1.5...1.5)
            let green = 90 + 4 * (beat + bump) + drift + noise
            self.process(green: green, brightness: 0.55, redRatio: 0.72, at: t)
        }
        timer.resume()
        syntheticTimer = timer
    }

    // MARK: Shared pipeline

    private var fingerLatched = false
    private var fingerSince: Double?
    private var exposureLocked = false
    private var warmthSmoothed: Double = 0
    private var lastBeatAt: Double = -1

    private func process(green: Double, brightness: Double, redRatio: Double, at time: Double) {
        // Finger present when the lens is mostly red and lit by the torch.
        // Latched with hysteresis so brushing the edge of the lens doesn't
        // flicker between found and lost.
        if !fingerLatched, redRatio > 0.55, brightness > 0.2 {
            fingerLatched = true
            fingerSince = time
        } else if fingerLatched, redRatio < 0.47 || brightness < 0.12 {
            fingerLatched = false
            fingerSince = nil
            if exposureLocked { exposureLocked = false; setExposureLocked(false) }
        }
        let fingerOn = fingerLatched

        // Once the fingertip has settled, freeze exposure so auto-exposure
        // stops chasing (and flattening) the pulse shimmer.
        if fingerOn, !exposureLocked, let since = fingerSince, time - since > 0.8 {
            exposureLocked = true
            setExposureLocked(true)
        }

        // The hot-and-cold signal: a bare scene sits near a third red, a lit
        // fingertip climbs well past half. Smoothed so it glides, not jumps.
        let closeness = min(max((redRatio - 0.36) / 0.22, 0), 1)
        let lit = min(brightness / 0.15, 1)
        warmthSmoothed += 0.25 * (closeness * lit - warmthSmoothed)
        let warmthNow = fingerOn ? 1 : warmthSmoothed

        greenWindow.append(green)
        timestamps.append(time)
        while let first = timestamps.first, time - first > windowSeconds {
            timestamps.removeFirst()
            greenWindow.removeFirst()
        }

        // Detrend against a ~1s local mean, then a whisper of smoothing.
        let detrended = detrend(greenWindow, timestamps: timestamps, over: 1.0)
        let signal = smooth3(detrended)

        // The adaptive bar a beat must clear: a share of the window's own
        // robust amplitude, so soft signals and strong ones both count fair.
        let threshold = 0.35 * percentile(signal.map(abs), 0.95)

        // A fresh peak at the tail of the signal is a beat happening right now.
        if fingerOn, threshold > 0, signal.count >= 3 {
            let i = signal.count - 2
            if signal[i] > threshold, signal[i] >= signal[i - 1], signal[i] > signal[i + 1],
               timestamps[i] - lastBeatAt >= refractory {
                lastBeatAt = timestamps[i]
                DispatchQueue.main.async { self.beatTick += 1 }
            }
        }

        let span = (timestamps.last ?? time) - (timestamps.first ?? time)
        var estimate: (bpm: Int, confident: Bool)? = nil
        if fingerOn, span >= windowSeconds * 0.6 {
            estimate = estimateBPM(signal, timestamps: timestamps, threshold: threshold)
        }

        let wave = normalize(Array(signal.suffix(120)))
        DispatchQueue.main.async {
            self.isFingerDetected = fingerOn
            self.warmth = warmthNow
            if fingerOn {
                self.samples = wave
                self.progress = min(span / self.windowSeconds, 1)
                if let estimate {
                    self.bpm = estimate.bpm
                    self.isConfident = estimate.confident
                }
            } else {
                self.samples = []
                self.progress = 0
                self.bpm = nil
                self.isConfident = false
            }
        }
    }

    /// Freezes or releases exposure and white balance. Locked while a
    /// fingertip rests on the lens; auto again once it lifts.
    private func setExposureLocked(_ locked: Bool) {
        guard let d = device else { return }
        try? d.lockForConfiguration()
        if locked {
            if d.isExposureModeSupported(.locked) { d.exposureMode = .locked }
            if d.isWhiteBalanceModeSupported(.locked) { d.whiteBalanceMode = .locked }
        } else {
            if d.isExposureModeSupported(.continuousAutoExposure) { d.exposureMode = .continuousAutoExposure }
            if d.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) { d.whiteBalanceMode = .continuousAutoWhiteBalance }
        }
        d.unlockForConfiguration()
    }

    // MARK: Signal math

    /// Subtracts each sample's local mean over the given span, removing
    /// breathing and pressure drift so beats stand tall around zero.
    private func detrend(_ values: [Double], timestamps: [Double], over seconds: Double) -> [Double] {
        guard values.count > 2 else { return values.map { _ in 0 } }
        var result = [Double](repeating: 0, count: values.count)
        var lo = 0, hi = 0, sum = 0.0
        for i in 0..<values.count {
            while hi < values.count, timestamps[hi] <= timestamps[i] + seconds / 2 {
                sum += values[hi]; hi += 1
            }
            while lo < values.count, timestamps[lo] < timestamps[i] - seconds / 2 {
                sum -= values[lo]; lo += 1
            }
            result[i] = values[i] - sum / Double(max(hi - lo, 1))
        }
        return result
    }

    /// Three-point moving average: enough to calm sensor noise, far too
    /// short to blur a beat.
    private func smooth3(_ values: [Double]) -> [Double] {
        guard values.count >= 3 else { return values }
        var result = values
        for i in 1..<values.count - 1 {
            result[i] = (values[i - 1] + values[i] + values[i + 1]) / 3
        }
        return result
    }

    private func percentile(_ values: [Double], _ p: Double) -> Double {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        let idx = min(Int(Double(sorted.count - 1) * p), sorted.count - 1)
        return sorted[idx]
    }

    private func median(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        let mid = sorted.count / 2
        return sorted.count % 2 == 0 ? (sorted[mid - 1] + sorted[mid]) / 2 : sorted[mid]
    }

    private func normalize(_ values: [Double]) -> [Double] {
        guard let lo = values.min(), let hi = values.max(), hi > lo else { return values.map { _ in 0 } }
        return values.map { ($0 - lo) / (hi - lo) }
    }

    /// Find peaks against the adaptive threshold, then read the rate from
    /// the MEDIAN interval after dropping gaps that look like missed beats
    /// (about double the median) or double-counts (about half of it).
    /// Confidence demands enough surviving beats that agree tightly.
    private func estimateBPM(_ signal: [Double], timestamps: [Double],
                             threshold: Double) -> (bpm: Int, confident: Bool)? {
        guard signal.count == timestamps.count, signal.count > 10, threshold > 0 else { return nil }
        var peaks: [Double] = []
        for i in 1..<signal.count - 1
        where signal[i] > threshold && signal[i] >= signal[i - 1] && signal[i] > signal[i + 1] {
            if let last = peaks.last, timestamps[i] - last < refractory { continue }
            peaks.append(timestamps[i])
        }
        guard peaks.count >= 4 else { return nil }

        let intervals = zip(peaks.dropFirst(), peaks).map { $0 - $1 }
        let med = median(intervals)
        guard med > 0 else { return nil }
        let kept = intervals.filter { $0 > 0.55 * med && $0 < 1.6 * med }
        guard !kept.isEmpty else { return nil }

        let finalMedian = median(kept)
        guard finalMedian > 0 else { return nil }
        let bpm = Int((60.0 / finalMedian).rounded())
        guard (40...220).contains(bpm) else { return nil }

        // Agreement: the middle spread of the kept intervals, relative to
        // their median. Tight rhythm reads well under 0.15.
        let spread = median(kept.map { abs($0 - finalMedian) }) / finalMedian
        let confident = kept.count >= 8 && spread < 0.15
        return (bpm, confident)
    }
}

extension PulseCameraReader: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        guard let base = CVPixelBufferGetBaseAddress(pixelBuffer) else { return }
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let ptr = base.assumingMemoryBound(to: UInt8.self)

        // Average a coarse grid over the CENTER of the frame only (BGRA).
        // The middle is pure fingertip; edges catch room light sneaking in.
        var rSum = 0.0, gSum = 0.0, bSum = 0.0, count = 0.0
        let step = 8
        var y = height / 4
        while y < height * 3 / 4 {
            let row = ptr + y * bytesPerRow
            var x = width / 4
            while x < width * 3 / 4 {
                let px = row + x * 4
                bSum += Double(px[0]); gSum += Double(px[1]); rSum += Double(px[2])
                count += 1; x += step
            }
            y += step
        }
        guard count > 0 else { return }
        let r = rSum / count, g = gSum / count, b = bSum / count
        let brightness = (r + g + b) / (3 * 255)
        let redRatio = r / max(r + g + b, 1)
        let time = CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sampleBuffer))
        process(green: g, brightness: brightness, redRatio: redRatio, at: time)
    }
}
