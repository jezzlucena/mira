#if os(iOS)
import StoreKit
import SwiftUI

/// Paywall view for Mira Premium — used in onboarding and Settings
struct SubscriptionView: View {
    /// If non-nil, shows "Continue with Free" (onboarding context)
    var onSkip: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var service: SubscriptionService
    @State private var selectedProduct: Product?
    @State private var isPurchasing = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var showManageSubscriptions = false

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                // Header
                headerSection

                if service.isPremium {
                    subscribedSection
                } else {
                    // Feature comparison
                    featureComparisonSection

                    // Plan cards
                    planCardsSection

                    // Purchase button
                    purchaseSection
                }
            }
            .padding()
        }
        .onChange(of: service.isPremium) { _, isPremium in
            if isPremium {
                onSkip?()
            }
        }
        .alert("Purchase Failed", isPresented: $showError) {
            Button("OK") {}
        } message: {
            Text(errorMessage ?? "An error occurred. Please try again.")
        }
        .manageSubscriptionsSheet(isPresented: $showManageSubscriptions)
    }

    // MARK: - Header

    @ViewBuilder
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "crown.fill")
                .font(.system(size: 60))
                .foregroundStyle(.yellow.gradient)
                .symbolEffect(.pulse)

            Text("Mira Premium")
                .font(.largeTitle.bold())

            Text("Sync across all your devices")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 20)
    }

    // MARK: - Already Subscribed

    @ViewBuilder
    private var subscribedSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)

            Text("You're Subscribed")
                .font(.title2.bold())

            if let expiration = service.expirationDate {
                Text("Renews \(expiration, style: .date)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Button("Manage Subscription") {
                showManageSubscriptions = true
            }
            .buttonStyle(.bordered)
        }
        .padding(.vertical, 20)
    }

    // MARK: - Feature Comparison

    @ViewBuilder
    private var featureComparisonSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("What's Included")
                .font(.headline)

            VStack(spacing: 12) {
                featureRow("Habit Tracking", free: true, premium: true)
                featureRow("Mood Logging", free: true, premium: true)
                featureRow("Analytics & Insights", free: true, premium: true)
                featureRow("Data Export", free: true, premium: true)
                featureRow("iCloud Sync", free: false, premium: true)
                featureRow("Apple Watch App", free: false, premium: true)
            }
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        }
    }

    private func featureRow(_ name: String, free: Bool, premium: Bool) -> some View {
        HStack {
            Text(name)
                .font(.subheadline)

            Spacer()

            HStack(spacing: 24) {
                Image(systemName: free ? "checkmark.circle.fill" : "xmark.circle")
                    .foregroundStyle(free ? .green : .secondary.opacity(0.4))
                    .frame(width: 40)

                Image(systemName: premium ? "checkmark.circle.fill" : "xmark.circle")
                    .foregroundStyle(premium ? .green : .secondary.opacity(0.4))
                    .frame(width: 40)
            }
        }
    }

    // MARK: - Plan Cards

    @ViewBuilder
    private var planCardsSection: some View {
        // Column headers
        HStack {
            Spacer()
            HStack(spacing: 24) {
                Text("Free")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .frame(width: 40)
                Text("Premium")
                    .font(.caption.bold())
                    .foregroundStyle(.tint)
                    .frame(width: 40)
            }
        }
        .padding(.horizontal)
        .offset(y: -20)

        if service.isLoading {
            ProgressView()
                .padding()
        } else {
            VStack(spacing: 12) {
                if let monthly = service.monthlyProduct {
                    planCard(
                        product: monthly,
                        label: "Monthly",
                        badge: nil
                    )
                }

                if let yearly = service.yearlyProduct {
                    planCard(
                        product: yearly,
                        label: "Yearly",
                        badge: "Save 25%"
                    )
                }
            }
        }
    }

    private func planCard(product: Product, label: String, badge: String?) -> some View {
        Button {
            selectedProduct = product
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(label)
                            .font(.headline)

                        if let badge {
                            Text(badge)
                                .font(.caption2.bold())
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(.yellow.opacity(0.2))
                                .foregroundStyle(.yellow)
                                .clipShape(Capsule())
                        }
                    }

                    Text(product.displayPrice + " / " + (product.id == SubscriptionService.monthlyProductID ? "month" : "year"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: selectedProduct?.id == product.id ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(selectedProduct?.id == product.id ? Color.accentColor : Color.secondary)
            }
            .padding()
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(
                                selectedProduct?.id == product.id ? Color.accentColor : .clear,
                                lineWidth: 2
                            )
                    }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Purchase Section

    @ViewBuilder
    private var purchaseSection: some View {
        VStack(spacing: 12) {
            GlassButton(
                "Subscribe",
                icon: "crown.fill",
                style: .large
            ) {
                purchaseSelected()
            }
            .disabled(selectedProduct == nil || isPurchasing)
            .frame(maxWidth: .infinity)

            Button("Restore Purchases") {
                Task {
                    await service.restorePurchases()
                }
            }
            .font(.footnote)
            .foregroundStyle(.secondary)

            if onSkip != nil {
                Button("Continue with Free") {
                    onSkip?()
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
            }

            Text("Subscriptions auto-renew. Cancel anytime in Settings.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.top, 4)
        }
        .padding(.bottom, 20)
    }

    // MARK: - Actions

    private func purchaseSelected() {
        guard let product = selectedProduct else { return }
        isPurchasing = true

        Task {
            do {
                _ = try await service.purchase(product)
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            isPurchasing = false
        }
    }
}

// MARK: - Preview

#Preview("Paywall") {
    SubscriptionView(onSkip: {})
        .withDependencies(.shared)
}

#Preview("Settings Context") {
    NavigationStack {
        SubscriptionView()
    }
    .withDependencies(.shared)
}
#endif
