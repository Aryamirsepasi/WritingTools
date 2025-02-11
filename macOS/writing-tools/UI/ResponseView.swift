import SwiftUI
import MarkdownUI
import UniformTypeIdentifiers

struct ChatMessage: Identifiable, Equatable {
    let id = UUID()
    let role: String // "user" or "assistant"
    let content: String
    let timestamp: Date = Date()
    
    static func == (lhs: ChatMessage, rhs: ChatMessage) -> Bool {
        lhs.id == rhs.id &&
        lhs.role == rhs.role &&
        lhs.content == rhs.content &&
        lhs.timestamp == rhs.timestamp
    }
}

struct ResponseView: View {
    @StateObject private var viewModel: ResponseViewModel
    @Environment(\.colorScheme) var colorScheme
    @AppStorage("use_gradient_theme") private var useGradientTheme = false
    @State private var inputText: String = ""
    @State private var isRegenerating: Bool = false
    @State private var uploadedFileName: String? = nil  // To show file upload confirmation

    init(content: String, selectedText: String, option: WritingOption) {
        self._viewModel = StateObject(wrappedValue: ResponseViewModel(content: content, selectedText: selectedText, option: option))
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Top toolbar with the Copy button.
                HStack {
                    Button(action: { viewModel.copyContent() }) {
                        Label(viewModel.showCopyConfirmation ? "Copied!" : "Copy",
                              systemImage: viewModel.showCopyConfirmation ? "checkmark" : "doc.on.doc")
                    }
                    .animation(.easeInOut, value: viewModel.showCopyConfirmation)
                    Spacer()
                }
                .padding()
                .background(Color(.windowBackgroundColor))

                // Chat messages area
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(viewModel.messages) { message in
                                ChatMessageView(message: message, fontSize: viewModel.fontSize)
                                    .id(message.id)
                                    .frame(maxWidth: .infinity, alignment: message.role == "user" ? .trailing : .leading)
                            }
                        }
                        .padding()
                    }
                    .onChange(of: viewModel.messages, initial: true) { oldValue, newValue in
                        if let lastId = newValue.last?.id {
                            withAnimation {
                                proxy.scrollTo(lastId, anchor: .bottom)
                            }
                        }
                    }
                }

                // Input area with attach button always shown.
                VStack(spacing: 8) {
                    Divider()
                    HStack(spacing: 8) {
                        // Attach button now allows images, PDFs, and videos.
                        Button(action: uploadFile) {
                            Image(systemName: "paperclip")
                                .frame(width: 25, height: 25)
                        }
                        .help("Upload an image, PDF, or video")

                        TextField("Ask a follow-up question...", text: $inputText)
                            .textFieldStyle(.plain)
                            .appleStyleTextField(text: inputText, isLoading: isRegenerating, onSubmit: sendMessage)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)

                    // Show confirmation for attached file
                    if let fileName = uploadedFileName {
                        HStack {
                            Text("Uploaded: \(fileName)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Button(action: {
                                uploadedFileName = nil
                                AppState.shared.selectedImages = []
                                AppState.shared.selectedVideos = []
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal)
                    }
                }
                .background(Color(.windowBackgroundColor))
            }

            // Overlay loading/processing animation while waiting for response.
            if isRegenerating {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                ProgressView("Processing...")
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .foregroundColor(.white)
                    .scaleEffect(1.2)
            }
        }
        .windowBackground(useGradient: useGradientTheme)
    }

    private func sendMessage() {
        guard !inputText.isEmpty else { return }
        let question = inputText
        inputText = ""
        isRegenerating = true
        viewModel.processFollowUpQuestion(question) {
            isRegenerating = false
        }
    }

    private func uploadFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [
            UTType.png,
            UTType.jpeg,
            UTType.tiff,
            UTType.gif,
            UTType.pdf,
            UTType.movie // NEW: allow video files
        ]

        if let window = NSApp.keyWindow {
            panel.beginSheetModal(for: window) { response in
                handlePanelResponse(response: response, panel: panel)
            }
        } else {
            panel.begin { response in
                handlePanelResponse(response: response, panel: panel)
            }
        }
    }

    private func handlePanelResponse(response: NSApplication.ModalResponse, panel: NSOpenPanel) {
        if response == .OK, let url = panel.url {
            do {
                let fileData = try Data(contentsOf: url)
                DispatchQueue.main.async {
                    if let fileType = UTType(filenameExtension: url.pathExtension.lowercased()) {
                        if fileType.conforms(to: .pdf) {
                            AppState.shared.selectedImages = [fileData]
                            AppState.shared.selectedVideos = []
                        } else if fileType.conforms(to: .movie) {
                            AppState.shared.selectedVideos = [fileData]
                            AppState.shared.selectedImages = []
                        } else {
                            AppState.shared.selectedImages.append(fileData)
                        }
                    } else {
                        // Fallback if the file type could not be determined
                        AppState.shared.selectedImages.append(fileData)
                    }
                    self.uploadedFileName = url.lastPathComponent
                }
            } catch {
                print("Error reading file: \(error.localizedDescription)")
            }
        }
    }
}

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
