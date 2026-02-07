import SwiftUI

/// Checkmark success animation after logging an entry
struct WatchConfirmationView: View {
    let habitName: String
    var onDismiss: (() -> Void)?

    @State private var showCheckmark = false
    @State private var scale: CGFloat = 0.5

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)
                .scaleEffect(scale)
                .opacity(showCheckmark ? 1 : 0)

            Text("Logged!")
                .font(.headline)
                .opacity(showCheckmark ? 1 : 0)

            Text(habitName)
                .font(.caption)
                .foregroundStyle(.secondary)
                .opacity(showCheckmark ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                showCheckmark = true
                scale = 1.0
            }

            #if os(watchOS)
            WKInterfaceDevice.current().play(.success)
            #endif

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                onDismiss?()
            }
        }
        .accessibilityLabel("Entry logged for \(habitName)")
    }
}
