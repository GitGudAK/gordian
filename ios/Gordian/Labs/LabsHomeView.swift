// Labs — TestFlight-only switch for the on-device engine (spike 005 outcome).

#if canImport(FoundationModels)

import SwiftUI
import FoundationModels

@available(iOS 26.0, *)
struct LabsHomeView: View {
    @AppStorage(FMEngine.toggleKey) private var fmEngineOn = false

    private var modelReady: Bool {
        SystemLanguageModel.default.availability == .available
    }

    var body: some View {
        List {
            Section {
                Toggle("Private Mode", isOn: $fmEngineOn)
                    .disabled(!modelReady)
            } header: {
                Text("Nothing leaves your iPhone")
            } footer: {
                if modelReady {
                    Text("Your dilemma, your answers, and your verdict stay on this device. No servers, no network — Private Mode works in airplane mode.\n\nSessions may feel a little plainer than usual: the model on your iPhone is smaller than the one Gordian normally uses.")
                } else {
                    Text(unavailableReason)
                }
            }
        }
        .navigationTitle("Private Mode")
    }

    // Tells the user exactly what to switch on, and where.
    private var unavailableReason: String {
        switch SystemLanguageModel.default.availability {
        case .available:
            return ""
        case .unavailable(let reason):
            switch reason {
            case .appleIntelligenceNotEnabled:
                return "Private Mode needs Apple Intelligence. Turn it on in Settings → Apple Intelligence & Siri, then come back."
            case .modelNotReady:
                return "Apple Intelligence is still downloading its model. Keep this iPhone on Wi-Fi and charged for a while, then come back."
            case .deviceNotEligible:
                return "This iPhone can't run Private Mode. It needs Apple Intelligence, which is available on iPhone 15 Pro and newer."
            @unknown default:
                return "Private Mode isn't available on this iPhone right now."
            }
        }
    }
}

#endif
