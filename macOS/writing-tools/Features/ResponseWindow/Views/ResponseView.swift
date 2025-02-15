import SwiftUI
import MarkdownUI
import UniformTypeIdentifiers


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
