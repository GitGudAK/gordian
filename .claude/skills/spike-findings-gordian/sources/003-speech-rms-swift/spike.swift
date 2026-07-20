// Spike 003: SFSpeechRecognizer + AVAudioEngine RMS parity with Android's onRmsChanged
// Proves: ONE input tap can feed BOTH live speech recognition and an RMS level meter
// (Android gives RMS for free via RecognitionListener.onRmsChanged; iOS/macOS does not).
//
// Swift 5.4 / macOS 11.3 SDK compatible. Same frameworks exist on iOS.
//
// Usage:
//   ./build.sh
//   ./spike003 status        # report mic/speech authorization + recognizer availability (no recording)
//   ./spike003 rms           # 8s: live ASCII RMS meter only (mic permission required)
//   ./spike003 full          # 12s: RMS meter + live partial transcription (mic + speech permission)

import Foundation
import AVFoundation
import Speech

// MARK: - Forensic log

struct LogEvent: Codable { let ts: String; let category: String; let message: String }

final class ForensicLog {
    private var events: [LogEvent] = []
    private let started = Date()
    private let iso = ISO8601DateFormatter()
    var rmsSamples: [Float] = []

    func log(_ category: String, _ message: String, echo: Bool = true) {
        events.append(LogEvent(ts: iso.string(from: Date()), category: category, message: message))
        if echo { print("[\(category)] \(message)"); fflush(stdout) }
    }

    func export(to path: String) {
        var counts: [String: Int] = [:]
        for e in events { counts[e.category, default: 0] += 1 }
        let stats: [String: String] = [
            "events": String(events.count),
            "durationSeconds": String(format: "%.1f", Date().timeIntervalSince(started)),
            "rmsSampleCount": String(rmsSamples.count),
            "rmsMin": rmsSamples.isEmpty ? "n/a" : String(format: "%.1f dB", rmsSamples.min()!),
            "rmsMax": rmsSamples.isEmpty ? "n/a" : String(format: "%.1f dB", rmsSamples.max()!),
            "rmsMean": rmsSamples.isEmpty ? "n/a" : String(format: "%.1f dB", rmsSamples.reduce(0, +) / Float(rmsSamples.count))
        ]
        struct Doc: Codable { let summary: [String: String]; let counts: [String: Int]; let events: [LogEvent] }
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? enc.encode(Doc(summary: stats, counts: counts, events: events)) {
            try? data.write(to: URL(fileURLWithPath: path))
            print("\n[LOG] forensic log exported to \(path)")
            print("[LOG] RMS stats: \(stats["rmsMin"]!) .. \(stats["rmsMax"]!) (mean \(stats["rmsMean"]!), \(rmsSamples.count) samples)")
        }
    }
}

let flog = ForensicLog()
let dir = (CommandLine.arguments[0] as NSString).deletingLastPathComponent

// MARK: - RMS math (the piece Android gives us for free)

// Computes RMS in dBFS from a PCM buffer, then normalizes to 0..1 the same way
// MainViewModel.updateRms() normalizes Android's rmsdB (-2..10) for the wave animation.
func rmsDb(from buffer: AVAudioPCMBuffer) -> Float {
    guard let data = buffer.floatChannelData?[0] else { return -160 }
    let n = Int(buffer.frameLength)
    guard n > 0 else { return -160 }
    var sum: Float = 0
    for i in 0..<n { sum += data[i] * data[i] }
    let rms = sqrt(sum / Float(n))
    return 20 * log10(max(rms, 1e-8)) // dBFS, ~-160 (silence) .. 0 (clipping)
}

// Map dBFS (-60..0 useful range) to 0..1 for the sentiment wave — replaces Android's (-2..10) mapping
func normalize(_ db: Float) -> Float {
    return min(max((db + 60) / 60, 0), 1)
}

func meterBar(_ level: Float, width: Int = 40) -> String {
    let filled = Int(level * Float(width))
    return "[" + String(repeating: "█", count: filled) + String(repeating: "·", count: width - filled) + "]"
}

// MARK: - Authorization probes

func speechAuthStatusString(_ s: SFSpeechRecognizerAuthorizationStatus) -> String {
    switch s {
    case .authorized: return "authorized"
    case .denied: return "denied"
    case .restricted: return "restricted"
    case .notDetermined: return "notDetermined"
    @unknown default: return "unknown"
    }
}

func micAuthStatusString(_ s: AVAuthorizationStatus) -> String {
    switch s {
    case .authorized: return "authorized"
    case .denied: return "denied"
    case .restricted: return "restricted"
    case .notDetermined: return "notDetermined"
    @unknown default: return "unknown"
    }
}

func runStatus() {
    flog.log("PROBE", "mic authorization: \(micAuthStatusString(AVCaptureDevice.authorizationStatus(for: .audio)))")
    flog.log("PROBE", "speech authorization: \(speechAuthStatusString(SFSpeechRecognizer.authorizationStatus()))")
    if let rec = SFSpeechRecognizer(locale: Locale(identifier: "en-US")) {
        flog.log("PROBE", "SFSpeechRecognizer(en-US) exists, available=\(rec.isAvailable), onDevice=\(rec.supportsOnDeviceRecognition)")
    } else {
        flog.log("ERROR", "SFSpeechRecognizer(en-US) could not be created")
    }
    // NB: keep the engine alive — AVAudioNode does not retain its engine, and
    // `AVAudioEngine().inputNode` alone segfaults when the temporary deallocates.
    let engine = AVAudioEngine()
    let fmt = engine.inputNode.inputFormat(forBus: 0)
    flog.log("PROBE", "input device format: \(fmt.sampleRate) Hz, \(fmt.channelCount) ch")
}

// MARK: - Live capture

func runCapture(seconds: Double, withSpeech: Bool) {
    // 1. Permissions
    let micSem = DispatchSemaphore(value: 0)
    var micOK = false
    AVCaptureDevice.requestAccess(for: .audio) { granted in micOK = granted; micSem.signal() }
    micSem.wait()
    flog.log(micOK ? "AUTH" : "ERROR", "microphone access: \(micOK ? "granted" : "DENIED")")
    guard micOK else {
        flog.log("HINT", "grant mic access to your terminal app in System Settings → Privacy & Security → Microphone, then rerun")
        return
    }

    var recognizer: SFSpeechRecognizer? = nil
    var request: SFSpeechAudioBufferRecognitionRequest? = nil
    var task: SFSpeechRecognitionTask? = nil

    if withSpeech {
        let spSem = DispatchSemaphore(value: 0)
        var spStatus = SFSpeechRecognizer.authorizationStatus()
        SFSpeechRecognizer.requestAuthorization { s in spStatus = s; spSem.signal() }
        spSem.wait()
        flog.log(spStatus == .authorized ? "AUTH" : "WARN", "speech recognition: \(speechAuthStatusString(spStatus))")
        if spStatus == .authorized {
            recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
            flog.log("PROBE", "recognizer available=\(recognizer?.isAvailable ?? false), onDevice=\(recognizer?.supportsOnDeviceRecognition ?? false)")
        } else {
            flog.log("WARN", "continuing with RMS only — speech not authorized")
        }
    }

    // 2. ONE engine, ONE tap — the pattern under test
    let engine = AVAudioEngine()
    let input = engine.inputNode
    let format = input.inputFormat(forBus: 0)
    flog.log("AUDIO", "engine input: \(format.sampleRate) Hz, \(format.channelCount) ch")

    var lastTranscript = ""
    if let rec = recognizer, rec.isAvailable {
        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        if rec.supportsOnDeviceRecognition { req.requiresOnDeviceRecognition = true }
        request = req
        task = rec.recognitionTask(with: req) { result, error in
            if let r = result {
                lastTranscript = r.bestTranscription.formattedString
                flog.log("SPEECH", "partial: \"\(lastTranscript)\"", echo: false)
            }
            if let e = error {
                flog.log("WARN", "recognition error: \(e.localizedDescription)", echo: false)
            }
        }
    }

    var latestLevel: Float = 0
    input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
        let db = rmsDb(from: buffer)
        latestLevel = normalize(db)
        flog.rmsSamples.append(db)
        request?.append(buffer)          // consumer 1: speech recognizer
    }

    engine.prepare()
    do {
        try engine.start()
    } catch {
        flog.log("ERROR", "engine start failed: \(error.localizedDescription)")
        return
    }

    print("\n🎙  SPEAK NOW — \(Int(seconds))s window. Say something about a decision you're wrestling with.\n")

    // 3. UI loop: redraw meter + transcript at 10 Hz (consumer 2: the sentiment wave stand-in)
    let deadline = Date().addingTimeInterval(seconds)
    while Date() < deadline {
        let transcriptTail = String(lastTranscript.suffix(50))
        print("\r\(meterBar(latestLevel)) \(String(format: "%4.2f", latestLevel))  \(transcriptTail)", terminator: "")
        fflush(stdout)
        RunLoop.current.run(until: Date().addingTimeInterval(0.1))
    }
    print("\n")

    // 4. Teardown
    input.removeTap(onBus: 0)
    engine.stop()
    request?.endAudio()
    // give the recognizer a moment to deliver the final result
    RunLoop.current.run(until: Date().addingTimeInterval(1.5))
    task?.cancel()

    flog.log("RESULT", "final transcript: \"\(lastTranscript)\"")
    let voiced = flog.rmsSamples.filter { $0 > -50 }.count
    flog.log("RESULT", "RMS samples: \(flog.rmsSamples.count) total, \(voiced) above -50 dBFS (voiced)")
}

// MARK: - Main

let mode = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "status"
flog.log("START", "spike003 mode=\(mode)")

switch mode {
case "status": runStatus()
case "rms": runCapture(seconds: 8, withSpeech: false)
case "full": runCapture(seconds: 12, withSpeech: true)
default: print("usage: spike003 [status|rms|full]")
}

flog.export(to: dir + "/spike003-log.json")
