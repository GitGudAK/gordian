// Voice capture — port of voice/VoiceRecognizer.kt using the spike-003 pattern:
// ONE AVAudioEngine input tap feeds BOTH SFSpeechRecognizer and a hand-computed RMS
// level (Android's onRmsChanged has no iOS equivalent). Engine is strongly retained
// (AVAudioNode does not retain its engine — releasing it mid-tap segfaults).

import Foundation
import AVFoundation
import Speech

@MainActor
final class SpeechCoordinator {
    var onStart: () -> Void = {}
    var onPartial: (String) -> Void = { _ in }
    var onResult: (String) -> Void = { _ in }
    var onError: (String) -> Void = { _ in }
    var onRmsChanged: (Float) -> Void = { _ in }

    private let engine = AVAudioEngine()
    private var recognizer: SFSpeechRecognizer?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var lastTranscript = ""
    private(set) var isListening = false

    func startListening() {
        Task {
            let micGranted = await AVAudioApplication.requestRecordPermission()
            guard micGranted else {
                onError("Microphone permission required for rapid reflection voice analysis.")
                return
            }
            let speechStatus = await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
            }
            guard speechStatus == .authorized else {
                onError("Speech recognition not available. Falling back to typing.")
                return
            }
            beginSession()
        }
    }

    private func beginSession() {
        stopListening()

        guard let recognizer = SFSpeechRecognizer(locale: Locale.current), recognizer.isAvailable else {
            onError("Speech recognition not available. Falling back to typing.")
            return
        }
        self.recognizer = recognizer

        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            onError("Audio session error: \(error.localizedDescription)")
            return
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }
        self.request = request
        lastTranscript = ""

        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                guard let self else { return }
                if let result {
                    self.lastTranscript = result.bestTranscription.formattedString
                    self.onPartial(self.lastTranscript)
                    if result.isFinal {
                        self.finish()
                    }
                } else if error != nil, self.isListening {
                    // Deliver whatever we heard rather than surfacing cancellation noise
                    self.finish()
                }
            }
        }

        let input = engine.inputNode
        let format = input.inputFormat(forBus: 0)
        // Capture the request locally: the tap runs on the audio thread, and it must not
        // touch MainActor state
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self, request] buffer, _ in
            let db = Self.rmsDb(from: buffer)
            let normalized = min(max((db + 60) / 60, 0), 1)
            request.append(buffer)
            Task { @MainActor in
                self?.onRmsChanged(normalized)
            }
        }

        engine.prepare()
        do {
            try engine.start()
            isListening = true
            onStart()
        } catch {
            onError("Failed to start listening: \(error.localizedDescription)")
            teardown()
        }
    }

    // Called by the UI's stop button; delivers the transcript captured so far
    func finishListening() {
        guard isListening else { return }
        request?.endAudio()
        // Give the recognizer a beat to deliver the final segment, then finish regardless
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(700))
            if self.isListening { self.finish() }
        }
    }

    private func finish() {
        guard isListening else { return }
        isListening = false
        let transcript = lastTranscript
        teardown()
        if transcript.isEmpty {
            onError("No speech recognized")
        } else {
            onResult(transcript)
        }
    }

    func stopListening() {
        isListening = false
        teardown()
    }

    private func teardown() {
        if engine.isRunning {
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
        }
        task?.cancel()
        task = nil
        request = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private nonisolated static func rmsDb(from buffer: AVAudioPCMBuffer) -> Float {
        guard let data = buffer.floatChannelData?[0] else { return -160 }
        let n = Int(buffer.frameLength)
        guard n > 0 else { return -160 }
        var sum: Float = 0
        for i in 0..<n { sum += data[i] * data[i] }
        return 20 * log10(max(sqrt(sum / Float(n)), 1e-8))
    }
}
