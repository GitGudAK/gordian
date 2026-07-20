// GUIDES/CALIBRATE tab — port of CalibrateTabScreen (decision guides + API key + purge)

import SwiftUI

struct CalibrateView: View {
    var viewModel: SessionViewModel
    @State private var expandedGuide: DecisionGuide?
    @State private var userApiKey = ""
    @State private var showPurgeConfirm = false
    @State private var purgeConfirmed = false
    @FocusState private var keyFieldFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let guide = expandedGuide {
                    guideDetail(guide)
                } else {
                    guideList
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .onAppear { userApiKey = viewModel.savedApiKey }
        .animation(.easeInOut(duration: 0.2), value: expandedGuide?.id)
    }

    // MARK: - Guide list

    private var guideList: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text("DECISION-MAKING GUIDES")
                    .font(.system(size: 20, weight: .heavy))
                    .tracking(2)
                    .foregroundColor(.goldPrimary)
                Text("Curated psychologist models and mental frameworks to bypass analytical loops and anxiety.")
                    .font(.system(size: 12))
                    .foregroundColor(.textMuted)
            }
            .padding(.vertical, 12)

            ForEach(DecisionGuide.all) { guide in
                Button {
                    expandedGuide = guide
                } label: {
                    HStack(spacing: 16) {
                        Image(systemName: guide.systemImage)
                            .font(.system(size: 17))
                            .foregroundColor(.goldPrimary)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(Color.goldPrimary.opacity(0.1)))
                            .overlay(Circle().stroke(Color.goldPrimary.opacity(0.3), lineWidth: 1))

                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(guide.title)
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(.white)
                                Spacer()
                                Text(guide.readTime)
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.textMuted)
                            }
                            Text(guide.description)
                                .font(.system(size: 11))
                                .foregroundColor(.textMuted)
                                .multilineTextAlignment(.leading)
                        }
                    }
                    .padding(18)
                    .gordianCard(cornerRadius: 20)
                }
            }

            // API configuration
            VStack(alignment: .leading, spacing: 12) {
                SectionLabel(text: "DEEP COGNITIVE CALIBRATION", tracking: 1)
                Text("Enter your Cognitive API key to unlock real-time, deep psychological analysis and personalized diagnostic breakthroughs.")
                    .font(.system(size: 11))
                    .foregroundColor(.textMuted)

                SecureField(
                    "",
                    text: $userApiKey,
                    prompt: Text("Enter API Key").font(.system(size: 12)).foregroundColor(.textMuted)
                )
                .focused($keyFieldFocused)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .modifier(GordianFieldStyle(focused: keyFieldFocused))
                .onChange(of: userApiKey) { _, newValue in
                    viewModel.saveApiKey(newValue)
                }

                Text("Note: If left empty, the app will fall back to local rule-based psychology models, keeping you fully functional.")
                    .font(.system(size: 10).italic())
                    .foregroundColor(.textMuted)
            }
            .padding(16)
            .gordianCard(cornerRadius: 16)

            // Purge history
            Button {
                showPurgeConfirm = true
            } label: {
                Text(purgeConfirmed ? "Log history successfully cleared." : "Purge Log History")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.redAccent)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.redAccent.opacity(0.15)))
            }
            .padding(.top, 10)
            .confirmationDialog("Purge all decision history?", isPresented: $showPurgeConfirm, titleVisibility: .visible) {
                Button("Purge Everything", role: .destructive) {
                    viewModel.clearHistory()
                    purgeConfirmed = true
                    Task {
                        try? await Task.sleep(for: .seconds(2))
                        purgeConfirmed = false
                    }
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    // MARK: - Guide detail

    private func guideDetail(_ guide: DecisionGuide) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Button {
                expandedGuide = nil
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .semibold))
                    Text("BACK TO METHODS")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(1)
                }
                .foregroundColor(.goldPrimary)
                .padding(.vertical, 4)
            }

            VStack(alignment: .leading, spacing: 4) {
                SectionLabel(text: guide.origin.uppercased(), size: 10)
                Text(guide.title)
                    .font(.system(size: 26, weight: .heavy))
                    .foregroundColor(.white)
                HStack(spacing: 12) {
                    Text(guide.readTime)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.textMuted)
                    Circle().fill(Color.textMuted).frame(width: 4, height: 4)
                    Text("Curated Blog View")
                        .font(.system(size: 11))
                        .foregroundColor(.textMuted)
                }
            }

            VStack(alignment: .leading, spacing: 16) {
                Text(guide.fullContent)
                    .font(.system(size: 14))
                    .lineSpacing(6)
                    .foregroundColor(.textLight)

                Divider().background(Color.white.opacity(0.05))

                VStack(alignment: .leading, spacing: 4) {
                    SectionLabel(text: "CORE TAKEAWAY", size: 10, tracking: 1)
                    Text(guide.coreTakeaway)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.goldPrimary.opacity(0.06)))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.goldPrimary.opacity(0.2), lineWidth: 1))
            }
            .padding(24)
            .gordianCard()

            Button {
                expandedGuide = nil
            } label: {
                Text("FINISH READING")
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(RoundedRectangle(cornerRadius: 20).fill(Color.goldPrimary))
            }
        }
        .padding(.vertical, 12)
    }
}
