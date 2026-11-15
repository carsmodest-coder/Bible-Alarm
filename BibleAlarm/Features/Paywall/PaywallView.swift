import StoreKit
import SwiftUI

/// Premium benefits and prices. No ads, ever.
struct PaywallView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    private let benefits: [(String, LocalizedStringKey)] = [
        ("text.cursor", "Strict mode: type the word or read the verse aloud"),
        ("brain.head.profile", "Memorize mode: quizzes on verses you have read"),
        ("books.vertical.fill", "Themed verse sets and reading plans"),
        ("waveform", "Waveform trim, fade-in and voice recording for alarm sounds"),
    ]

    var body: some View {
        @Bindable var store = model.store
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    Image(systemName: "sunrise.fill")
                        .font(.system(size: 52))
                        .foregroundStyle(Theme.accent)
                        .padding(.top, 12)
                    Text("Bible Alarm Premium")
                        .font(.largeTitle.weight(.bold))
                        .multilineTextAlignment(.center)
                    Text("No ads, ever. No tracking.")
                        .font(.headline)
                        .foregroundStyle(Theme.accent)

                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(benefits, id: \.0) { benefit in
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: benefit.0)
                                    .foregroundStyle(Theme.accent)
                                    .frame(width: 28)
                                Text(benefit.1)
                                    .foregroundStyle(Color.white)
                                Spacer(minLength: 0)
                            }
                        }
                    }
                    .padding(18)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: 20))

                    if model.isPremium {
                        Label("Premium is active", systemImage: "checkmark.seal.fill")
                            .font(.headline)
                            .foregroundStyle(Theme.accent)
                    } else if model.store.premiumProducts.isEmpty {
                        Text(model.store.isLoading ? "Loading prices…" : "Purchases are not available in this build yet.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.secondaryText)
                            .multilineTextAlignment(.center)
                    } else {
                        ForEach(model.store.premiumProducts, id: \.id) { product in
                            Button {
                                Task { await model.store.purchase(product) }
                            } label: {
                                VStack(spacing: 4) {
                                    Text(product.displayName)
                                    Text(priceLine(for: product))
                                        .font(.subheadline.weight(.regular))
                                }
                            }
                            .buttonStyle(PrimaryButtonStyle())
                            .disabled(model.store.isPurchasing)
                        }
                    }

                    Button("Restore Purchases") {
                        Task { await model.store.restore() }
                    }
                    .font(.subheadline)

                    Text("Bible translations stay free. Premium pays for extra features and supports this ministry. Subscriptions renew automatically until cancelled in your App Store account settings.")
                        .font(.footnote)
                        .foregroundStyle(Theme.secondaryText)
                        .multilineTextAlignment(.center)
                }
                .padding(24)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .alert("Bible Alarm", isPresented: Binding(
                get: { store.message != nil },
                set: { if !$0 { store.message = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(store.message ?? "")
            }
        }
        .preferredColorScheme(.dark)
    }

    private func priceLine(for product: Product) -> String {
        guard let subscription = product.subscription else {
            return String(localized: "\(product.displayPrice) once")
        }
        let period = subscription.subscriptionPeriod.unit == .year
            ? String(localized: "\(product.displayPrice) per year")
            : String(localized: "\(product.displayPrice) per month")
        if let offer = subscription.introductoryOffer, offer.paymentMode == .freeTrial {
            return String(localized: "7-day free trial, then \(period)")
        }
        return period
    }
}

/// Optional tips. "Support this ministry."
struct TipJarView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var store = model.store
        List {
            Section {
                VStack(spacing: 10) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(Theme.accent)
                    Text("Support this ministry")
                        .font(.title2.weight(.semibold))
                    Text("Bible Alarm has no ads and never will. If it helps you, a tip helps keep it going.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.secondaryText)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .listRowBackground(Color.clear)
            }

            Section {
                if model.store.tipProducts.isEmpty {
                    Text(model.store.isLoading ? "Loading prices…" : "Purchases are not available in this build yet.")
                        .foregroundStyle(Theme.secondaryText)
                }
                ForEach(model.store.tipProducts, id: \.id) { product in
                    Button {
                        Task { await model.store.purchase(product) }
                    } label: {
                        HStack {
                            Text(product.displayName)
                                .foregroundStyle(Color.white)
                            Spacer()
                            Text(product.displayPrice)
                                .foregroundStyle(Theme.accent)
                        }
                    }
                    .disabled(model.store.isPurchasing)
                }
            }
            .cardRow()
        }
        .screenBackground()
        .navigationTitle("Tip jar")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Bible Alarm", isPresented: Binding(
            get: { store.message != nil },
            set: { if !$0 { store.message = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(store.message ?? "")
        }
    }
}
