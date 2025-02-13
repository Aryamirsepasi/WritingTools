import SwiftUI
import MarkdownUI

struct ChatMessageView: View {
    let message: ChatMessage
    let fontSize: CGFloat

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if message.role == "assistant" {
                bubbleView(role: message.role)
                Spacer(minLength: 15)
            } else {
                Spacer(minLength: 15)
                bubbleView(role: message.role)
            }
        }
        .padding(.top, 4)
    }

    @ViewBuilder
    private func bubbleView(role: String) -> some View {
        VStack(alignment: role == "assistant" ? .leading : .trailing, spacing: 2) {
            Markdown(message.content)
                .font(.system(size: fontSize))
                .textSelection(.enabled)
                .chatBubbleStyle(isFromUser: message.role == "user")
            Text(message.timestamp.formatted(.dateTime.hour().minute()))
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(.bottom, 2)
        }
        .frame(maxWidth: 500, alignment: role == "assistant" ? .leading : .trailing)
    }
}
