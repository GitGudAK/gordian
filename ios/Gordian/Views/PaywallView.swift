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
                Spacer(minLength: 12)

                KnotGlyph(color: .goldPrimary)
                    .frame(width: 56, height: 56)

                Text("YOUR WEEK WITH GORDIAN IS UP")
                    .font(.system(size: 20, weight: .heavy))
                    .tracking(1.5)
                    .foregroundColor(.textLight)
                    .multilineTextAlignment(.center)

                Text("Every session is written for your exact dilemma. Keep untying knots with full access.")
                    .font(.system(size: 14))
                    .foregroundColor(.textMuted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 12)

                VStack(spacing: 12) {
                    if entitlements.products.isEmpty {
                        #if DEBUG
                        if ProcessInfo.processInfo.arguments.contains("-demoPaywall") {
                            planButton(label: "Monthly", priceText: "$4.99 / month", isLifetime: false, isBestValue: false) {}
                            planButton(label: "Annual", priceText: "$29.99 / year", isLifetime: false, isBestValue: true) {}
                            planButton(label: "Lifetime", priceText: "$69.99 once, forever", isLifetime: true, isBestValue: false) {}
                        } else {
                            loadingPlans
                        }
                        #else
                        loadingPlans
                        #endif
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
        .scrollBounceBehavior(.basedOnSize)
        // Apple's own redemption sheet — the App Store owns the code, we never
        // unlock anything ourselves (guideline 3.1.1).
        .offerCodeRedemption(isPresented: $showRedeemSheet) { result in
            if case .success = result {
                Task { await entitlements.refreshEntitlements() }
            }
        }
        // Returning to this screen (or coming back from Settings/App Store)
        // retries a failed load without the user hunting for the button.
        .task {
            if entitlements.products.isEmpty && entitlements.productState != .loading {
                await entitlements.loadProducts()
            }
        }
    }

    @ViewBuilder
    private var loadingPlans: some View {
        if entitlements.productState == .failed {
            VStack(spacing: 12) {
                Text("Plans couldn't load")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.textLight)
                Text("The App Store didn't answer. Check your connection and try again — your access and any past purchase are safe.")
                    .font(.system(size: 13))
                    .foregroundColor(.textMuted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Button {
                    Task { await entitlements.loadProducts() }
                } label: {
                    Text("Try again")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(RoundedRectangle(cornerRadius: 16).fill(Color.goldPrimary))
                }
            }
            .padding(.vertical, 8)
        } else {
            VStack(spacing: 10) {
                ProgressView()
                    .tint(.goldPrimary)
                Text("Loading plans…")
                    .font(.system(size: 12))
                    .foregroundColor(.textMuted)
            }
            .padding(.vertical, 24)
        }
    }

    @ViewBuilder
    private func productButton(_ product: Product) -> some View {
        planButton(
            label: label(for: product),
            priceText: price(for: product),
            isLifetime: product.id == EntitlementManager.lifetimeID,
            isBestValue: product.id == EntitlementManager.annualID
        ) {
            purchasing = true
            Task {
                defer { purchasing = false }
                try? await entitlements.purchase(product)
            }
        }
    }

    @ViewBuilder
    private func planButton(label: String, priceText: String, isLifetime: Bool, isBestValue: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Text(label)
                    .font(.system(size: 15, weight: .bold))
                Text(priceText)
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
            .overlay(alignment: .topTrailing) {
                if isBestValue {
                    Text("BEST VALUE")
                        .font(.system(size: 9, weight: .heavy))
                        .tracking(1)
                        .foregroundColor(.goldPrimary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.darkBackground))
                        .overlay(Capsule().stroke(Color.goldPrimary.opacity(0.6), lineWidth: 1))
                        .offset(x: -10, y: -9)
                }
            }
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
