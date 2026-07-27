// Labs — TestFlight-only switch for the on-device engine (spike 005 outcome).
// The spike harnesses are gone; their source lives in the findings skill.

#if canImport(FoundationModels)

import SwiftUI
import FoundationModels

@available(iOS 26.0, *)
struct LabsHomeView: View {
    @AppStorage(FMEngine.toggleKey) private var fmEngineOn = false

    var body: some View {
        List {
            Section {
                Toggle("All sessions are on-device (complete privacy)", isOn: $fmEngineOn)
            } footer: {
                if SystemLanguageModel.default.availability != .available {
                    Text("The on-device model isn't available right now — sessions use the standard engine until it is.")
                }
            }
        }
        .navigationTitle("Labs")
    }
}

#endif
