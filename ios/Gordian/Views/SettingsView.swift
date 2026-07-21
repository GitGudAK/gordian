// Settings sheet — API key and data management, moved out of the Guides tab (ticket #4)

import SwiftUI
import SwiftData

struct SettingsView: View {
    var viewModel: SessionViewModel
    @Environment(\.dismiss) private var dismiss
    @Query private var decisions: [DecisionLog]
    @State private var apiKey = ""
    @State private var showPurgeConfirm = false
    @FocusState private var keyFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                Color.darkBackground.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Gemini API key
                        VStack(alignment: .leading, spacing: 12) {
                            SectionLabel(text: "GEMINI API KEY", tracking: 1)
                            Text("Add your own Gemini API key to get questions written for your exact dilemma. Without one, Gordian uses its built-in question set — fully functional, just less personal.")
                                .font(.footnote)
                                .foregroundColor(.textMuted)
                            SecureField(
                                "",
                                text: $apiKey,
                                prompt: Text("API key").font(.footnote).foregroundColor(.textMuted)
                            )
                            .focused($keyFocused)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .modifier(GordianFieldStyle(focused: keyFocused))
                            .onChange(of: apiKey) { _, newValue in
                                viewModel.saveApiKey(newValue)
                            }
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
        .onAppear { apiKey = viewModel.savedApiKey }
    }
}
