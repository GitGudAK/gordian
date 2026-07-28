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
                Toggle("Use on-device model", isOn: $fmEngineOn)
                    .disabled(!modelReady)
                Link("How to turn on Apple Intelligence", destination: Self.appleIntelligenceHelp)
                    .font(.footnote)
                    .tint(.goldPrimary)
            } footer: {
                Text("Sessions run entirely on your iPhone. Nothing is sent to a server.\n\n\(requirement)")
            }
        }
        .navigationTitle("Private Mode")
    }

    private var requirement: String {
        switch SystemLanguageModel.default.availability {
        case .available:
            return "Requires Apple Intelligence, which is on."
        case .unavailable(.appleIntelligenceNotEnabled):
            return "Requires Apple Intelligence. Turn it on in Settings → Apple Intelligence & Siri."
        case .unavailable(.modelNotReady):
            return "Requires Apple Intelligence, which is still finishing setup. Keep this iPhone on Wi-Fi and charged."
        case .unavailable(.deviceNotEligible):
            return "Requires Apple Intelligence, available on iPhone 15 Pro and newer."
        case .unavailable:
            return "Requires Apple Intelligence."
        }
    }
}

#endif
