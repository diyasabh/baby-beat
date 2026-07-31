import AVFoundation
import Combine
import UIKit

/// Reads a heartbeat from the rear camera with the flash on, using
/// photoplethysmography: a fingertip rests on the lens, the torch lights it
/// like a tiny nightlight, and every pulse of blood shifts the redness the
/// camera sees. We track that shimmer and count the beats.
///
/// On the simulator there is no camera, so a synthetic fingertip signal is
/// fed through the exact same pipeline.
final class PulseCameraReader: NSObject, ObservableObject {
    @Published var bpm: Int?
    @Published var isFingerDetected = false
    @Published var samples: [Double] = []   // recent normalized signal for the live wave
    @Published var progress: Double = 0      // 0...1 over the measurement window

    private let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "babybeat.camera")
    private var device: AVCaptureDevice?

    private var brightnessWindow: [Double] = []
    private var timestamps: [Double] = []
    private let windowSeconds: Double = 15

    func start() {
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

        if device.hasTorch {
            try? device.lockForConfiguration()
            try? device.setTorchModeOn(level: 1.0)
            device.unlockForConfiguration()
        }
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
                self.process(brightness: 0.05, redRatio: 0.3, at: t)
                return
            }
            // A believable pulse: main beat, a soft dicrotic bump, slow drift, noise.
            let hz = self.syntheticTargetBPM / 60.0
            let beat = sin(2 * .pi * hz * t)
            let bump = 0.3 * sin(4 * .pi * hz * t + 0.8)
            let drift = 0.15 * sin(0.1 * t)
            let noise = Double.random(in: -0.06...0.06)
            let brightness = 0.55 + 0.08 * (beat + bump + drift + noise)
            self.process(brightness: brightness, redRatio: 0.72, at: t)
        }
        timer.resume()
        syntheticTimer = timer
    }

    // MARK: Shared pipeline

    private func process(brightness: Double, redRatio: Double, at time: Double) {
        // Finger present when the lens is mostly red and lit by the torch.
        let fingerOn = redRatio > 0.55 && brightness > 0.2
        brightnessWindow.append(brightness)
        timestamps.append(time)

        while let first = timestamps.first, time - first > windowSeconds {
            timestamps.removeFirst()
            brightnessWindow.removeFirst()
        }

        let normalized = normalize(brightnessWindow)
        let span = (timestamps.last ?? time) - (timestamps.first ?? time)
        let estimate = fingerOn && span >= windowSeconds * 0.6
            ? estimateBPM(normalized, timestamps: timestamps) : nil

        DispatchQueue.main.async {
            self.isFingerDetected = fingerOn
            if fingerOn {
                self.samples = Array(normalized.suffix(120))
                self.progress = min(span / self.windowSeconds, 1)
                if let estimate { self.bpm = estimate }
            } else {
                self.samples = []
                self.progress = 0
                self.bpm = nil
            }
        }
    }

    private func normalize(_ values: [Double]) -> [Double] {
        guard let lo = values.min(), let hi = values.max(), hi > lo else { return values.map { _ in 0 } }
        return values.map { ($0 - lo) / (hi - lo) }
    }

    /// Count peaks in the normalized signal and turn the average gap into bpm.
    private func estimateBPM(_ signal: [Double], timestamps: [Double]) -> Int? {
        guard signal.count == timestamps.count, signal.count > 10 else { return nil }
        var peaks: [Double] = []
        for i in 1..<signal.count - 1 where signal[i] > 0.6 && signal[i] >= signal[i - 1] && signal[i] > signal[i + 1] {
            if let last = peaks.last, timestamps[i] - last < 0.28 { continue } // refractory, caps ~210
            peaks.append(timestamps[i])
        }
        guard peaks.count >= 3 else { return nil }
        let intervals = zip(peaks.dropFirst(), peaks).map { $0 - $1 }
        let mean = intervals.reduce(0, +) / Double(intervals.count)
        guard mean > 0 else { return nil }
        let bpm = Int((60.0 / mean).rounded())
        return (40...220).contains(bpm) ? bpm : nil
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

        // Average a coarse grid of pixels (BGRA layout).
        var rSum = 0.0, gSum = 0.0, bSum = 0.0, count = 0.0
        let step = 8
        var y = 0
        while y < height {
            let row = ptr + y * bytesPerRow
            var x = 0
            while x < width {
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
        process(brightness: brightness, redRatio: redRatio, at: time)
    }
}
