// Spike 006: speechanalyzer-transcription
//
// Validates: given spoken dilemmas, when transcribed by SpeechAnalyzer +
// SpeechTranscriber (the iOS 26 on-device pipeline), then accuracy and
// latency beat the current SFSpeechRecognizer path — which already failed
// once on-device (requiresOnDeviceRecognition before model download).
//
// Measures: asset download need/time, time-to-first-volatile-result,
// time-to-final, and the transcript itself. All exported via the log.

#if canImport(FoundationModels)

import SwiftUI
import Speech
import AVFoundation

@available(iOS 26.0, *)
struct LabsSpeechView: View {
    @State private var log = LabsLog()
    @State private var engine = LabsSpeechEngine()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 10) {
                    SectionLabel(text: "LIVE TRANSCRIPTION", tracking: 1)
                    Text(engine.volatileText.isEmpty && engine.finalText.isEmpty
                         ? "Tap start and speak a dilemma."
                         : engine.finalText + " " + engine.volatileText)
                        .font(.system(size: 16))
                        .foregroundColor(.textLight)
                        .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
                        .padding(12)
                        .gordianCard(cornerRadius: 12)

                    Text(engine.status)
                        .font(.footnote)
                        .foregroundColor(.textMuted)

                    Button(engine.isRunning ? "Stop" : "Start listening") {
                        Task {
                            if engine.isRunning {
                                await engine.stop(log: log)
                            } else {
                                await engine.start(log: log)
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(16)
                .gordianCard(cornerRadius: 16)

                if let url = log.exportURL(name: "spike-006-speechanalyzer") {
                    ShareLink(item: url) {
                        Label("Export forensic log (\(log.events.count) events)", systemImage: "square.and.arrow.up")
                    }
                }
            }
            .padding(20)
        }
        .background(Color.darkBackground)
        .navigationTitle("006 · SpeechAnalyzer")
    }
}

@available(iOS 26.0, *)
@Observable
final class LabsSpeechEngine {
    var volatileText = ""
    var finalText = ""
    var status = "Idle"
    var isRunning = false

    private var analyzer: SpeechAnalyzer?
    private var transcriber: SpeechTranscriber?
    private var inputBuilder: AsyncStream<AnalyzerInput>.Continuation?
    private var resultsTask: Task<Void, Never>?
    private let audioEngine = AVAudioEngine()
    private var startInstant: ContinuousClock.Instant?
    private var sawFirstVolatile = false

    func start(log: LabsLog) async {
        guard !isRunning else { return }
        volatileText = ""; finalText = ""; sawFirstVolatile = false
        let clock = ContinuousClock()

        let granted = await AVAudioApplication.requestRecordPermission()
        guard granted else {
            status = "Mic permission denied"
            log.log("error", "mic permission denied")
            return
        }

        do {
            let transcriber = SpeechTranscriber(
                locale: Locale(identifier: "en-US"),
                transcriptionOptions: [],
                reportingOptions: [.volatileResults],
                attributeOptions: []
            )
            self.transcriber = transcriber

            // On-device model assets may need a one-time download — measure it,
            // since this is exactly where the SFSpeechRecognizer path fell over
            let assetStart = clock.now
            if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
                status = "Downloading speech assets…"
                log.log("assets", "download needed")
                try await request.downloadAndInstall()
                log.log("assets", "downloaded", data: ["ms": "\((clock.now - assetStart).msString)"])
            } else {
                log.log("assets", "already installed")
            }

            let analyzer = SpeechAnalyzer(modules: [transcriber])
            self.analyzer = analyzer

            guard let format = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber]) else {
                status = "No compatible audio format"
                log.log("error", "no compatible analyzer format")
                return
            }
            log.log("setup", "analyzer format", data: ["format": "\(format)"])

            let (inputSequence, builder) = AsyncStream<AnalyzerInput>.makeStream()
            inputBuilder = builder

            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement)
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            let input = audioEngine.inputNode
            let tapFormat = input.outputFormat(forBus: 0)
            let converter = AVAudioConverter(from: tapFormat, to: format)

            input.installTap(onBus: 0, bufferSize: 4096, format: tapFormat) { buffer, _ in
                guard let converter else { return }
                let ratio = format.sampleRate / tapFormat.sampleRate
                let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 16
                guard let out = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else { return }
                var err: NSError?
                var fed = false
                converter.convert(to: out, error: &err) { _, outStatus in
                    if fed {
                        outStatus.pointee = .noDataNow
                        return nil
                    }
                    fed = true
                    outStatus.pointee = .haveData
                    return buffer
                }
                if err == nil, out.frameLength > 0 {
                    builder.yield(AnalyzerInput(buffer: out))
                }
            }

            resultsTask = Task { [weak self] in
                guard let self, let transcriber = self.transcriber else { return }
                do {
                    for try await result in transcriber.results {
                        let text = String(result.text.characters)
                        await MainActor.run {
                            if result.isFinal {
                                self.finalText += text + " "
                                self.volatileText = ""
                            } else {
                                self.volatileText = text
                            }
                        }
                        if !self.sawFirstVolatile, let s = self.startInstant {
                            self.sawFirstVolatile = true
                            log.log("latency", "first volatile result", data: ["ms": "\((clock.now - s).msString)"])
                        }
                        log.log(result.isFinal ? "final" : "volatile", text)
                    }
                } catch {
                    log.log("error", "results stream", data: ["error": String(describing: error)])
                }
            }

            audioEngine.prepare()
            try audioEngine.start()
            startInstant = clock.now
            try await analyzer.start(inputSequence: inputSequence)

            isRunning = true
            status = "Listening (on-device)"
            log.log("session", "started")
        } catch {
            status = "Start failed: \(error.localizedDescription)"
            log.log("error", "start failed", data: ["error": String(describing: error)])
        }
    }

    func stop(log: LabsLog) async {
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        inputBuilder?.finish()
        do {
            try await analyzer?.finalizeAndFinishThroughEndOfInput()
        } catch {
            log.log("error", "finalize", data: ["error": String(describing: error)])
        }
        resultsTask?.cancel()
        isRunning = false
        status = "Stopped"
        log.log("session", "stopped", data: ["finalTranscript": finalText])
    }
}

@available(iOS 26.0, *)
private extension Duration {
    var msString: String { "\(Int(Double(components.seconds) * 1000 + Double(components.attoseconds) / 1e15))" }
}

#endif
