// Labs is TestFlight-only: sandbox receipts identify TestFlight installs,
// so App Store users (and this Mac's local builds) never see the entry point.

#if canImport(FoundationModels)

import Foundation

enum LabsGate {
    static var isTestFlight: Bool {
        Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
    }
}

#endif
