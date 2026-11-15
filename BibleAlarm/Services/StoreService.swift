import Foundation
import Observation
import StoreKit

/// Product identifiers, following the pattern in the project brief.
enum ProductID {
    static let prefix = "com.ryder.biblealarm"
    static let monthly = prefix + ".premium.monthly"
    static let yearly = prefix + ".premium.yearly"
    static let lifetime = prefix + ".premium.lifetime"
    static let tipSmall = prefix + ".tip.small"
    static let tipMedium = prefix + ".tip.medium"
    static let tipLarge = prefix + ".tip.large"

    static let premium: Set<String> = [monthly, yearly, lifetime]
    static let tips: Set<String> = [tipSmall, tipMedium, tipLarge]
    static let all: Set<String> = premium.union(tips)
}

/// Purchases through the App Store (StoreKit 2). The App Store is the source of truth for Premium.
/// Until the products exist in App Store Connect, `products` is simply empty.
@MainActor
@Observable
final class StoreService {
    private(set) var products: [Product] = []
    private(set) var hasPremiumPurchase = false
    private(set) var isLoading = false
    private(set) var isPurchasing = false
    var message: String?

    private var updatesTask: Task<Void, Never>?

    var premiumProducts: [Product] {
        products.filter { ProductID.premium.contains($0.id) }.sorted { $0.price < $1.price }
    }

    var tipProducts: [Product] {
        products.filter { ProductID.tips.contains($0.id) }.sorted { $0.price < $1.price }
    }

    /// Call once when the app starts.
    func start() {
        guard updatesTask == nil else { return }
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                if case .verified(let transaction) = update {
                    await transaction.finish()
                }
                await self?.refreshEntitlements()
            }
        }
        Task { await load() }
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            products = try await Product.products(for: ProductID.all)
        } catch {
            products = []
        }
        await refreshEntitlements()
    }

    func refreshEntitlements() async {
        var premium = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               ProductID.premium.contains(transaction.productID),
               transaction.revocationDate == nil {
                premium = true
            }
        }
        hasPremiumPurchase = premium
    }

    func purchase(_ product: Product) async {
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                    await refreshEntitlements()
                    message = String(localized: "Thank you! Your purchase is complete.")
                } else {
                    message = String(localized: "The purchase could not be verified.")
                }
            case .pending:
                message = String(localized: "Your purchase is waiting for approval.")
            case .userCancelled:
                break
            @unknown default:
                break
            }
        } catch {
            message = String(localized: "The purchase did not go through. Please try again.")
        }
    }

    func restore() async {
        isLoading = true
        defer { isLoading = false }
        try? await AppStore.sync()
        await refreshEntitlements()
        message = hasPremiumPurchase
            ? String(localized: "Your purchases have been restored.")
            : String(localized: "No purchases were found to restore.")
    }
}
