import Foundation

struct ChatMessage: Identifiable, Equatable {
    let id = UUID()
    let role: String
    let content: String
    let timestamp: Date = Date()

    static func == (lhs: ChatMessage, rhs: ChatMessage) -> Bool {
        lhs.id == rhs.id &&
        lhs.role == rhs.role &&
        lhs.content == rhs.content &&
        lhs.timestamp == rhs.timestamp
    }
}
