// Labs — TestFlight-only spike harness for the all-Apple stack exploration.
// Reachable from Settings on TestFlight builds compiled with the iOS 26 SDK.

#if canImport(FoundationModels)

import SwiftUI

@available(iOS 26.0, *)
struct LabsHomeView: View {
    var body: some View {
        List {
            Section {
                NavigationLink("005 · Foundation Model reflections") { LabsFMView() }
                NavigationLink("006 · SpeechAnalyzer transcription") { LabsSpeechView() }
                NavigationLink("007 · Liquid Glass identity") { LabsGlassView() }
            } footer: {
                Text("Spikes for the all-Apple stack. Run each, then export its forensic log and share it back for analysis. Nothing here touches your real sessions.")
            }
        }
        .navigationTitle("Labs")
    }
}

#endif
