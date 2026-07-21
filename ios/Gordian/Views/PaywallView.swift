// Shown when the 7-day trial has ended and no purchase is active. Replaces the
// Focus home; Logs and Guides stay accessible (the user's data is theirs).
// Redemption lanes: subscription offer codes in-app; lifetime promo codes via
// the App Store redeem page.

import SwiftUI
import StoreKit

struct PaywallView: View {
    var entitlements = EntitlementManager.shared
    @State private var purchasing = false
    @State private var showRedeemSheet = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer(minLength: 24)

                KnotGlyph(color: .goldPrimary)
                    .frame(width: 56, height: 56)

                Text("YOUR WEEK WITH GORDIAN IS UP")
                    .font(.system(size: 20, weight: .heavy))
                    .tracking(1.5)
                    .foregroundColor(.textLight)
                    .multilineTextAlignment(.center)

                Text("Every session is written by AI for your exact dilemma. Keep untying knots with full access.")
                    .font(.system(size: 14))
                    .foregroundColor(.textMuted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 12)

                VStack(spacing: 12) {
                    if entitlements.products.isEmpty {
                        ProgressView()
                            .tint(.goldPrimary)
                            .padding(.vertical, 24)
                        Text("Loading plans…")
                            .font(.system(size: 12))
                            .foregroundColor(.textMuted)
                    } else {
                        ForEach(entitlements.products, id: \.id) { product in
                            productButton(product)
                        }
                    }
                }

                VStack(spacing: 14) {
                    Button("Redeem a code") { showRedeemSheet = true }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.goldPrimary)

                    Button("Restore purchases") {
                        Task { await entitlements.restore() }
                    }
                    .font(.system(size: 13))
                    .foregroundColor(.textMuted)
                }
                .padding(.top, 4)

                Spacer(minLength: 24)
            }
            .padding(.horizontal, 24)
        }
        .offerCodeRedemption(isPresented: $showRedeemSheet) { _ in
            Task { await entitlements.refreshEntitlements() }
        }
    }

    @ViewBuilder
    private func productButton(_ product: Product) -> some View {
        let isLifetime = product.id == EntitlementManager.lifetimeID
        Button {
            purchasing = true
            Task {
                defer { purchasing = false }
                try? await entitlements.purchase(product)
            }
        } label: {
            VStack(spacing: 3) {
                Text(label(for: product))
                    .font(.system(size: 15, weight: .bold))
                Text(price(for: product))
                    .font(.system(size: 12))
                    .opacity(0.8)
            }
            .foregroundColor(isLifetime ? .goldPrimary : .black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isLifetime ? Color.darkSurface : Color.goldPrimary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isLifetime ? Color.goldPrimary.opacity(0.5) : .clear, lineWidth: 1)
            )
        }
        .disabled(purchasing)
    }

    private func label(for product: Product) -> String {
        switch product.id {
        case EntitlementManager.monthlyID: return "Monthly"
        case EntitlementManager.annualID: return "Annual"
        default: return "Lifetime"
        }
    }

    private func price(for product: Product) -> String {
        switch product.id {
        case EntitlementManager.monthlyID: return "\(product.displayPrice) / month"
        case EntitlementManager.annualID: return "\(product.displayPrice) / year"
        default: return "\(product.displayPrice) once, forever"
        }
    }
}
