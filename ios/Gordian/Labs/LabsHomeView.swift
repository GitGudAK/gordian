// Labs — TestFlight-only spike harness for the all-Apple stack exploration.
// Reachable from Settings on TestFlight builds compiled with the iOS 26 SDK.

#if canImport(FoundationModels)

import SwiftUI
import FoundationModels

@available(iOS 26.0, *)
struct LabsHomeView: View {
    @AppStorage(FMEngine.toggleKey) private var fmEngineOn = false

    var body: some View {
        List {
            Section {
                NavigationLink("005 · Foundation Model reflections") { LabsFMView() }
                NavigationLink("006 · SpeechAnalyzer transcription") { LabsSpeechView() }
            } footer: {
                Text("Isolated spike harnesses. Export each forensic log and share it back for analysis.")
            }

            Section {
                Toggle("On-device engine for real sessions", isOn: $fmEngineOn)
            } footer: {
                Text(SystemLanguageModel.default.availability == .available
                     ? "When on, YOUR real sessions (dilemma → questions → verdict) run on the Foundation Model instead of the proxy. Full experience, fully on-device. Refusals in this mode never count strikes. Flip off to return to the proxy."
                     : "Model unavailable on this device right now — the toggle has no effect until it is.")
            }
        }
        .navigationTitle("Labs")
    }
}

#endif
