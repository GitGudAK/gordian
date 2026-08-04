// Settings sheet — membership, notifications, and data management (ticket #4)

import SwiftUI
import SwiftData
import StoreKit

struct SettingsView: View {
    var viewModel: SessionViewModel
    @Environment(\.dismiss) private var dismiss
    @Query private var decisions: [DecisionLog]
    @State private var showPurgeConfirm = false
    @State private var showRedeemSheet = false
    @State private var showPlansSheet = false
    @State private var followUpsEnabled = FollowUpManager.shared.followUpsEnabled
    @State private var dailyKnotEnabled = FollowUpManager.shared.dailyKnotEnabled
    @State private var weeklyRecapEnabled = FollowUpManager.shared.weeklyRecapEnabled

    private var membershipStatus: String {
        let e = EntitlementManager.shared
        if e.hasLifetime { return "Lifetime access." }
        if e.hasSubscription { return "Subscription active." }
        if e.isInTrial {
            let d = e.trialDaysRemaining
            return "Free week: \(d) \(d == 1 ? "day" : "days") left."
        }
        return "Your free week has ended."
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.darkBackground.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Membership
                        VStack(alignment: .leading, spacing: 12) {
                            SectionLabel(text: "MEMBERSHIP", tracking: 1)
                            Text(membershipStatus)
                                .font(.footnote)
                                .foregroundColor(.textMuted)
                            // Plans are reachable at any time, not only once the
                            // trial lapses — people can buy early, and App
                            // Review can see the whole purchase flow without
                            // waiting seven days (guideline 2.1).
                            if !EntitlementManager.shared.isPurchased {
                                Button {
                                    showPlansSheet = true
                                } label: {
                                    Text("See plans")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.black)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 44)
                                        .background(RoundedRectangle(cornerRadius: 12)
                                            .fill(Color.goldPrimary))
                                }
                            }
                            Button {
                                showRedeemSheet = true
                            } label: {
                                Text("Redeem a code")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.goldPrimary)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 44)
                                    .background(RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.goldPrimary.opacity(0.4), lineWidth: 1))
                            }
                            Button {
                                Task { await EntitlementManager.shared.restore() }
                            } label: {
                                Text("Restore purchases")
                                    .font(.system(size: 13))
                                    .foregroundColor(.textMuted)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .padding(16)
                        .gordianCard(cornerRadius: 16)

                        // Notifications — one toggle per type, nothing imposed
                        VStack(alignment: .leading, spacing: 16) {
                            SectionLabel(text: "NOTIFICATIONS", tracking: 1)

                            notifToggle(
                                "Decision follow-ups",
                                description: "A few days after a verdict: did you act on it?",
                                isOn: $followUpsEnabled
                            ) { FollowUpManager.shared.followUpsEnabled = $0 }

                            Divider().background(Color.white.opacity(0.05))

                            notifToggle(
                                "The Daily Knot",
                                description: "One reflective question every morning at 9:00.",
                                isOn: $dailyKnotEnabled
                            ) { FollowUpManager.shared.dailyKnotEnabled = $0 }

                            Divider().background(Color.white.opacity(0.05))

                            notifToggle(
                                "Weekly recap",
                                description: "Your week in decisions, Sunday evening. Skipped on quiet weeks.",
                                isOn: $weeklyRecapEnabled
                            ) { FollowUpManager.shared.weeklyRecapEnabled = $0 }
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

                        // About / legal
                        VStack(alignment: .leading, spacing: 12) {
                            SectionLabel(text: "ABOUT GORDIAN", tracking: 1)
                            Text("Gordian is a self-reflection exercise that helps you reach your own decision faster. It reflects your own answers and is not medical, legal, financial, or professional advice. For serious decisions, consult a qualified professional. Your choices are always your own.")
                                .font(.footnote)
                                .foregroundColor(.textMuted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(16)
                        .gordianCard(cornerRadius: 16)

                        // Labs: spike harness. Exists only in iOS 26 SDK builds
                        // (Xcode Cloud) and only surfaces on TestFlight installs.
                        #if canImport(FoundationModels)
                        if #available(iOS 26.0, *), LabsGate.isTestFlight {
                            NavigationLink {
                                LabsHomeView()
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        SectionLabel(text: "PRIVATE MODE", tracking: 1)
                                        Text("Run sessions entirely on this iPhone")
                                            .font(.footnote)
                                            .foregroundColor(.textMuted)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12))
                                        .foregroundColor(.textMuted)
                                }
                                .padding(16)
                            }
                            .gordianCard(cornerRadius: 16)
                        }
                        #endif
                    }
                    .padding(24)
                }
            }
            .scrollBounceBehavior(.basedOnSize)
            // Apple's own redemption sheet — codes are redeemed BY the App
            // Store, in-app, never by us (guideline 3.1.1).
            .offerCodeRedemption(isPresented: $showRedeemSheet) { result in
                if case .success = result {
                    Task { await EntitlementManager.shared.refreshEntitlements() }
                }
            }
            .sheet(isPresented: $showPlansSheet) {
                PaywallView()
                    .background(Color.darkBackground.ignoresSafeArea())
                    .preferredColorScheme(.dark)
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

    private func notifToggle(_ title: String, description: String, isOn: Binding<Bool>, apply: @escaping (Bool) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle(isOn: isOn) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.white)
            }
            .tint(.goldPrimary)
            .onChange(of: isOn.wrappedValue) { _, newValue in
                apply(newValue)
            }
            Text(description)
                .font(.footnote)
                .foregroundColor(.textMuted)
        }
    }
}
