// Access model (Phase 3.5): free 7-day trial from first launch, then Gordian
// requires an active subscription or the lifetime unlock. StoreKit 2 only —
// entitlements resolve from Transaction.currentEntitlements, fully offline,
// no accounts, consistent with the anonymous/local-only privacy constant.
//
// Coupon lanes (Apple-native, configured in App Store Connect):
//  - 3 months free  → subscription Offer Codes, redeemed in-app
//  - lifetime free  → Promo Codes for the lifetime non-consumable (App Store redeem)

import Foundation
import StoreKit
import Observation

@Observable
@MainActor
final class EntitlementManager {
    static let shared = EntitlementManager()

    static let monthlyID = "plus.monthly"
    static let annualID = "plus.annual"
    static let lifetimeID = "plus.lifetime"
    static let trialLength: TimeInterval = 7 * 24 * 60 * 60
    private static let firstLaunchKey = "gordian_first_launch"

    private(set) var hasSubscription = false
    private(set) var hasLifetime = false
    private(set) var products: [Product] = []

    /// The paywall must never dead-end on "Loading plans…". Product loading can
    /// fail for reasons the user can act on (no network) and reasons they
    /// can't (App Store outage, products not yet approved), so the state is
    /// explicit and always recoverable.
    enum ProductLoadState: Equatable {
        case idle, loading, loaded, failed
    }
    private(set) var productState: ProductLoadState = .idle

    private var updatesTask: Task<Void, Never>?

    var isPurchased: Bool { hasSubscription || hasLifetime }

    // MARK: - Trial (anchored at first launch)

    var trialEndDate: Date {
        let stored = UserDefaults.standard.double(forKey: Self.firstLaunchKey)
        if stored > 0 {
            return Date(timeIntervalSince1970: stored).addingTimeInterval(Self.trialLength)
        }
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: Self.firstLaunchKey)
        return Date().addingTimeInterval(Self.trialLength)
    }

    var isInTrial: Bool { !isPurchased && Date() < trialEndDate }

    var trialDaysRemaining: Int {
        max(0, Int(ceil(trialEndDate.timeIntervalSince(Date()) / 86_400)))
    }

    /// The single gate the rest of the app asks.
    var hasAccess: Bool { isPurchased || isInTrial }

    // MARK: - StoreKit

    func start() {
        _ = trialEndDate // anchor the trial clock on first ever launch
        updatesTask = Task {
            for await update in Transaction.updates {
                if let transaction = try? update.payloadValue {
                    await transaction.finish()
                }
                await refreshEntitlements()
            }
        }
        Task {
            await refreshEntitlements()
            await loadProducts()
        }
    }

    func refreshEntitlements() async {
        var subscription = false
        var lifetime = false
        for await entitlement in Transaction.currentEntitlements {
            guard let transaction = try? entitlement.payloadValue else { continue }
            switch transaction.productID {
            case Self.lifetimeID: lifetime = true
            case Self.monthlyID, Self.annualID: subscription = true
            default: break
            }
        }
        #if DEBUG
        // -grantLifetime / -revokeLifetime tooling: simctl launches can't
        // complete StoreKit purchases, so testing entitled states needs this
        if UserDefaults.standard.bool(forKey: "gordian_debug_lifetime") { lifetime = true }
        #endif
        hasSubscription = subscription
        hasLifetime = lifetime
    }

    #if DEBUG
    func debugSetLifetime(_ granted: Bool) {
        UserDefaults.standard.set(granted, forKey: "gordian_debug_lifetime")
        Task { await refreshEntitlements() }
    }
    #endif

    func loadProducts() async {
        guard productState != .loading else { return }
        productState = .loading
        let ids = [Self.monthlyID, Self.annualID, Self.lifetimeID]
        // Two quiet retries with backoff: StoreKit commonly fails the first
        // call right after cold launch or a network handoff.
        for attempt in 0..<3 {
            if let loaded = try? await Product.products(for: ids), !loaded.isEmpty {
                products = ids.compactMap { id in loaded.first { $0.id == id } }
                productState = .loaded
                return
            }
            if attempt < 2 {
                try? await Task.sleep(for: .seconds(attempt == 0 ? 1 : 3))
            }
        }
        productState = .failed
    }

    func purchase(_ product: Product) async throws {
        let result = try await product.purchase()
        if case .success(let verification) = result,
           let transaction = try? verification.payloadValue {
            await transaction.finish()
            await refreshEntitlements()
        }
    }

    func restore() async {
        try? await AppStore.sync()
        await refreshEntitlements()
    }

    #if DEBUG
    /// -expireTrial launch arg: pretend the install is 8 days old.
    func debugExpireTrial() {
        UserDefaults.standard.set(Date().addingTimeInterval(-8 * 86_400).timeIntervalSince1970,
                                  forKey: Self.firstLaunchKey)
    }

    /// -resetTrial launch arg: fresh-install trial state.
    func debugResetTrial() {
        UserDefaults.standard.removeObject(forKey: Self.firstLaunchKey)
    }
    #endif
}
