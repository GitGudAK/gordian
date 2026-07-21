// Settings sheet — API key and data management, moved out of the Guides tab (ticket #4)

import SwiftUI
import SwiftData

struct SettingsView: View {
    var viewModel: SessionViewModel
    @Environment(\.dismiss) private var dismiss
    @Query private var decisions: [DecisionLog]
    @State private var showPurgeConfirm = false
    @State private var followUpsEnabled = FollowUpManager.shared.followUpsEnabled

    var body: some View {
        NavigationStack {
            ZStack {
                Color.darkBackground.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Follow-ups
                        VStack(alignment: .leading, spacing: 12) {
                            SectionLabel(text: "FOLLOW-UPS", tracking: 1)
                            Toggle(isOn: $followUpsEnabled) {
                                Text("Decision follow-ups")
                                    .font(.subheadline)
                                    .foregroundColor(.white)
                            }
                            .tint(.goldPrimary)
                            .onChange(of: followUpsEnabled) { _, newValue in
                                FollowUpManager.shared.followUpsEnabled = newValue
                            }
                            Text("A few days after a verdict, Gordian asks whether you acted on it. Answer straight from the notification.")
                                .font(.footnote)
                                .foregroundColor(.textMuted)
                        }
                        .padding(16)
                        .gordianCard(cornerRadius: 16)

                        // Data
                        VStack(alignment: .leading, spacing: 12) {
                            SectionLabel(text: "YOUR DATA", tracking: 1)
                            Text("Sessions are stored only on this device.")
                                .font(.footnote)
                                .foregroundColor(.textMuted)
                            Button {
                                showPurgeConfirm = true
                            } label: {
                                Text(decisions.isEmpty ? "No logs to delete" : "Delete All Logs (\(decisions.count))")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(decisions.isEmpty ? .textMuted : .redAccent)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 44)
                                    .background(RoundedRectangle(cornerRadius: 12)
                                        .fill(decisions.isEmpty ? Color.darkSurfaceVariant : Color.redAccent.opacity(0.15)))
                            }
                            .disabled(decisions.isEmpty)
                            .confirmationDialog(
                                "Delete \(decisions.count) log \(decisions.count == 1 ? "entry" : "entries")? This cannot be undone.",
                                isPresented: $showPurgeConfirm,
                                titleVisibility: .visible
                            ) {
                                Button("Delete Everything", role: .destructive) {
                                    viewModel.clearHistory()
                                }
                                Button("Cancel", role: .cancel) {}
                            }
                        }
                        .padding(16)
                        .gordianCard(cornerRadius: 16)
                    }
                    .padding(24)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.goldPrimary)
                }
            }
        }
    }
}
