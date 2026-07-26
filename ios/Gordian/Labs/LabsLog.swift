// Labs forensic log — the observability layer for the all-Apple spikes.
// Spikes run on a TestFlight device this Mac cannot observe, so every event
// is timestamped here and exported as JSON via the share sheet; the exported
// file IS the spike result that comes back for analysis.
//
// The whole Labs tree compiles only under the iOS 26 SDK (Xcode Cloud).
// Local Xcode 16.4 builds skip it entirely via canImport(FoundationModels).

#if canImport(FoundationModels)

import Foundation
import SwiftUI

@available(iOS 26.0, *)
@Observable
final class LabsLog {
    struct Event: Codable, Identifiable {
        var id = UUID()
        let ts: String
        let tag: String
        let message: String
        var data: [String: String] = [:]
    }

    private(set) var events: [Event] = []

    private static let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    func log(_ tag: String, _ message: String, data: [String: String] = [:]) {
        events.append(Event(ts: Self.iso.string(from: Date()), tag: tag, message: message, data: data))
    }

    func clear() { events.removeAll() }

    /// Writes the event log to a temp JSON file and returns its URL for ShareLink.
    func exportURL(name: String) -> URL? {
        let payload: [String: AnyEncodable] = [
            "spike": AnyEncodable(name),
            "exportedAt": AnyEncodable(Self.iso.string(from: Date())),
            "device": AnyEncodable(UIDevice.current.model + " iOS " + UIDevice.current.systemVersion),
            "eventCount": AnyEncodable(events.count),
            "events": AnyEncodable(events)
        ]
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(name)-\(Int(Date().timeIntervalSince1970)).json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(payload) else { return nil }
        try? data.write(to: url)
        return url
    }
}

// Minimal type-erased Encodable so the export payload can mix strings and events
struct AnyEncodable: Encodable {
    private let encodeFunc: (Encoder) throws -> Void
    init<T: Encodable>(_ value: T) { self.encodeFunc = value.encode }
    func encode(to encoder: Encoder) throws { try encodeFunc(encoder) }
}

/// Labs is TestFlight-only: sandbox receipts identify TestFlight installs,
/// so App Store users (and this Mac's local builds) never see the entry point.
enum LabsGate {
    static var isTestFlight: Bool {
        Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
    }
}

#endif
