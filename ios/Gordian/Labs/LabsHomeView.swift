// Labs — TestFlight-only switch for the on-device engine (spike 005 outcome).

#if canImport(FoundationModels)

import SwiftUI
import FoundationModels

@available(iOS 26.0, *)
struct LabsHomeView: View {
    @AppStorage(FMEngine.toggleKey) private var fmEngineOn = false

    private static let appleIntelligenceHelp =
        URL(string: "https://support.apple.com/en-us/121115")!

    private var modelReady: Bool {
        SystemLanguageModel.default.availability == .available
    }

    var body: some View {
        List {
            Section {
                Toggle("Use the on-device model", isOn: $fmEngineOn)
                    .disabled(!modelReady)
                if !modelReady {
                    Link("How to turn on Apple Intelligence", destination: Self.appleIntelligenceHelp)
                        .font(.footnote)
                }
            } header: {
                Text("Private Mode")
            } footer: {
                if modelReady {
                    Text("Sessions run entirely on your iPhone. Your dilemma, your answers, and your verdict never leave the device — Private Mode even works in airplane mode.")
                } else {
                    Text("Requires Apple Intelligence. \(unavailableDetail)")
                }
            }
        }
        .navigationTitle("Private Mode")
    }

    private var unavailableDetail: String {
        switch SystemLanguageModel.default.availability {
        case .available:
            return ""
        case .unavailable(let reason):
            switch reason {
            case .appleIntelligenceNotEnabled:
                return "Turn it on in Settings → Apple Intelligence & Siri, then come back."
            case .modelNotReady:
                return "It's still finishing setup. Keep this iPhone on Wi-Fi and charged for a while, then come back."
            case .deviceNotEligible:
                return "This iPhone doesn't support it. Apple Intelligence is available on iPhone 15 Pro and newer."
            @unknown default:
                return "It isn't available on this iPhone right now."
            }
        }
    }
}

#endif
