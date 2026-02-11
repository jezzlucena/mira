import SwiftUI
import StoreKit

/// Shown on Apple Watch when the user does not have a Mira Premium subscription
struct WatchSubscriptionGateView: View {
    @EnvironmentObject var subscriptionService: SubscriptionService
    @State private var isRestoring = false

    var body: some View {
        ContentUnavailableView {
            Label("Mira Premium Required", systemImage: "crown.fill")
        } description: {
            Text("The Apple Watch app requires a Mira Premium subscription. Subscribe on your iPhone to get started.")
        } actions: {
            Button {
                isRestoring = true
                Task {
                    await subscriptionService.restorePurchases()
                    isRestoring = false
                }
            } label: {
                if isRestoring {
                    ProgressView()
                } else {
                    Text("Restore Purchases")
                }
            }
            .disabled(isRestoring)
        }
    }
}

#Preview {
    WatchSubscriptionGateView()
        .environmentObject(SubscriptionService())
}
