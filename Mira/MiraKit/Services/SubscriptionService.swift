import Combine
import Foundation
import StoreKit
import SwiftUI

/// Manages Mira Premium subscription state via StoreKit 2
@MainActor
public final class SubscriptionService: ObservableObject {
    // MARK: - Product IDs

    public static let monthlyProductID = "com.jezzlucena.mira.premium.monthly"
    public static let yearlyProductID = "com.jezzlucena.mira.premium.yearly"
    private static let allProductIDs: Set<String> = [monthlyProductID, yearlyProductID]

    // MARK: - Published State

    @Published public private(set) var currentTier: Tier = UserDefaults.standard.bool(forKey: "isPremiumSubscriber") ? .premium : .free
    @Published public private(set) var products: [Product] = []
    @Published public private(set) var isLoading = false
    @Published public private(set) var expirationDate: Date?

    // MARK: - Computed

    public var isPremium: Bool { currentTier == .premium }

    public var monthlyProduct: Product? {
        products.first { $0.id == Self.monthlyProductID }
    }

    public var yearlyProduct: Product? {
        products.first { $0.id == Self.yearlyProductID }
    }

    // MARK: - Static Cached Check

    /// Synchronous check for Container.init() — reads cached UserDefaults value
    public static var cachedIsPremium: Bool {
        UserDefaults.standard.bool(forKey: "isPremiumSubscriber")
    }

    // MARK: - Private

    private var transactionListener: Task<Void, Never>?

    // MARK: - Types

    public enum Tier {
        case free
        case premium
    }

    // MARK: - Init

    public init() {
        transactionListener = listenForTransactions()

        Task {
            await refreshSubscriptionStatus()
            await loadProducts()
        }
    }

    deinit {
        transactionListener?.cancel()
    }

    // MARK: - Public API

    public func loadProducts() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let storeProducts = try await Product.products(for: Self.allProductIDs)
            // Sort: monthly first, then yearly
            products = storeProducts.sorted { a, _ in
                a.id == Self.monthlyProductID
            }
        } catch {
            print("Failed to load products: \(error)")
        }
    }

    public func purchase(_ product: Product) async throws -> StoreKit.Transaction? {
        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await refreshSubscriptionStatus()
            await transaction.finish()
            return transaction

        case .pending:
            // Ask to Buy or other pending state
            return nil

        case .userCancelled:
            return nil

        @unknown default:
            return nil
        }
    }

    /// Syncs with the App Store and refreshes subscription status.
    /// Throws if the App Store sync fails.
    public func restorePurchases() async throws {
        try await AppStore.sync()
        await refreshSubscriptionStatus()
    }

    public func refreshSubscriptionStatus() async {
        var foundPremium = false
        var latestExpiration: Date?

        for await result in Transaction.currentEntitlements {
            guard let transaction = try? checkVerified(result) else { continue }

            if Self.allProductIDs.contains(transaction.productID) {
                foundPremium = true
                if let expiry = transaction.expirationDate {
                    if latestExpiration == nil || expiry > latestExpiration! {
                        latestExpiration = expiry
                    }
                }
            }
        }

        currentTier = foundPremium ? .premium : .free
        expirationDate = latestExpiration
        UserDefaults.standard.set(foundPremium, forKey: "isPremiumSubscriber")
    }

    // MARK: - Private Helpers

    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                if let transaction = try? await self.checkVerified(result) {
                    await self.refreshSubscriptionStatus()
                    await transaction.finish()
                }
            }
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let safe):
            return safe
        }
    }
}
