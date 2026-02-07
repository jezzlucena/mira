import SwiftUI

/// Compact sentiment display for watchOS
struct WatchSentimentBadge: View {
    let sentiment: Int

    var body: some View {
        Text(sentimentEmojiFor(sentiment))
            .font(.caption)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background {
                Capsule()
                    .fill(sentimentColorFor(sentiment).opacity(0.2))
            }
    }
}
