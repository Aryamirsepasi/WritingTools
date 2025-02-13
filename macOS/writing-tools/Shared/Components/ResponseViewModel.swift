import SwiftUI
import MarkdownUI
import UniformTypeIdentifiers

final class ResponseViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var fontSize: CGFloat = 14
    @Published var showCopyConfirmation: Bool = false
    
    let selectedText: String
    let option: WritingOption
    
    init(content: String, selectedText: String, option: WritingOption) {
        self.selectedText = selectedText
        self.option = option
        self.messages.append(ChatMessage(role: "assistant", content: content))
    }
    
    func processFollowUpQuestion(_ question: String, completion: @escaping () -> Void) {
        DispatchQueue.main.async {
            self.messages.append(ChatMessage(role: "user", content: question))
        }
        
        Task {
            do {
                let conversationHistory = messages.map { message in
                    return "\(message.role == "user" ? "User" : "Assistant"): \(message.content)"
                }.joined(separator: "\n\n")
                
                let contextualPrompt = """
                Previous conversation:
                \(conversationHistory)
                
                User's new question: \(question)
                
                Respond to the user's question while maintaining context from the previous conversation.
                """
                
                let result = try await AppState.shared.activeProvider.processText(
                    systemPrompt: """
                    You are a writing and coding assistant. Your sole task is to respond to the user's instruction thoughtfully and comprehensively.
                    If the instruction is a question, provide a detailed answer.
                    Use Markdown formatting to make your response more readable.
                    """,
                    userPrompt: contextualPrompt,
                    images: AppState.shared.selectedImages,
                    videos: AppState.shared.selectedVideos,
                    streaming: true
                )
                
                DispatchQueue.main.async {
                    self.messages.append(ChatMessage(role: "assistant", content: result))
                    completion()
                }
            } catch {
                print("Error processing follow-up: \(error)")
                completion()
            }
        }
    }
    
    func clearConversation() {
        messages.removeAll()
    }
    
    func copyContent() {
        let conversationText = messages.map { message in
            return "\(message.role.capitalized): \(message.content)"
        }.joined(separator: "\n\n")
        
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(conversationText, forType: .string)
        
        showCopyConfirmation = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.showCopyConfirmation = false
        }
    }
}
