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
    @State private var followUpsEnabled = FollowUpManager.shared.followUpsEnabled
    @State private var dailyKnotEnabled = FollowUpManager.shared.dailyKnotEnabled
    @State private var weeklyRecapEnabled = FollowUpManager.shared.weeklyRecapEnabled

    private var membershipStatus: String {
        let e = EntitlementManager.shared
        if e.hasLifetime { return "Lifetime access. Thank you for untying the big knot." }
        if e.hasSubscription { return "Subscription active. Every session is yours." }
        if e.isInTrial {
            let d = e.trialDaysRemaining
            return "Free week in progress. \(d) \(d == 1 ? "day" : "days") remaining."
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
                                description: "A few days after a verdict, Gordian asks whether you acted on it. Answer straight from the notification.",
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
                                description: "Sunday evening: how many knots you untied and acted on. Skipped on quiet weeks.",
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
                            Text("Gordian is a self-reflection exercise that helps you reach your own decision faster. It does not provide medical, legal, financial, psychological, or professional advice. Its output reflects your own answers and is not a recommendation. For decisions with serious consequences, consult a qualified professional. You are always responsible for your choices.")
                                .font(.footnote)
                                .foregroundColor(.textMuted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(16)
                        .gordianCard(cornerRadius: 16)
                    }
                    .padding(24)
                }
            }
            .sheet(isPresented: $showRedeemSheet) {
                RedeemCodeView()
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
