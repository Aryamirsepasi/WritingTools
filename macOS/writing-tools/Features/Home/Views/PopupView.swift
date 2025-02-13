import SwiftUI

struct PopupView: View {
    @ObservedObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme
    @StateObject private var commandsManager = CustomCommandsManager()
    let closeAction: () -> Void
    @AppStorage("use_gradient_theme") private var useGradientTheme = false
    @State private var customText: String = ""
    @State private var loadingOptions: Set<String> = []
    @State private var isCustomLoading: Bool = false
    @State private var showingCustomCommands = false

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Button(action: closeAction) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .padding(.top, 8)
                .padding(.leading, 8)

                Spacer()

                Button(action: { showingCustomCommands = true }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .padding(.top, 8)
                .padding(.trailing, 8)
            }

            HStack(spacing: 8) {
                TextField(
                    appState.selectedText.isEmpty ? "Describe your change..." : "Describe your change...",
                    text: $customText
                )
                .textFieldStyle(.plain)
                .appleStyleTextField(
                    text: customText,
                    isLoading: isCustomLoading,
                    onSubmit: processCustomChange
                )
            }
            .padding(.horizontal)

            if !appState.selectedText.isEmpty || !appState.selectedImages.isEmpty {
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 8),
                        GridItem(.flexible(), spacing: 8)
                    ], spacing: 8) {
                        ForEach(WritingOption.allCases) { option in
                            OptionButton(
                                option: option,
                                action: { processOption(option) },
                                isLoading: loadingOptions.contains(option.id)
                            )
                        }

                        ForEach(commandsManager.commands) { command in
                            CustomOptionButton(
                                command: command,
                                action: { processCustomCommand(command) },
                                isLoading: loadingOptions.contains(command.id.uuidString)
                            )
                        }
                    }
                    .padding(.horizontal, 8)
                }
                .padding(.horizontal, 8)
            }
        }
        .padding(.bottom, 8)
        .modifier(PopupBackgroundModifier(useGradientTheme: useGradientTheme))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.gray.opacity(0.2), lineWidth: 1)
        )
        .sheet(isPresented: $showingCustomCommands) {
            CustomCommandsView(commandsManager: commandsManager)
        }
    }

    private func processCustomCommand(_ command: CustomCommand) {
        loadingOptions.insert(command.id.uuidString)
        appState.isProcessing = true

        Task {
            defer {
                loadingOptions.remove(command.id.uuidString)
                appState.isProcessing = false
            }

            do {
                let result = try await appState.activeProvider.processText(
                    systemPrompt: command.prompt,
                    userPrompt: appState.selectedText,
                    images: appState.selectedImages,
                    videos: appState.selectedVideos,
                    streaming: false
                )

                if command.useResponseWindow {
                    await MainActor.run {
                        let window = ResponseWindow(
                            title: command.name,
                            content: result,
                            selectedText: appState.selectedText,
                            option: .proofread
                        )

                        WindowManager.shared.addResponseWindow(window)
                        window.makeKeyAndOrderFront(nil)
                        window.orderFrontRegardless()
                    }
                } else {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(result, forType: .string)

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        simulatePaste()
                    }
                }

                closeAction()
            } catch {
                print("Error processing custom command: \(error.localizedDescription)")
            }
        }
    }

    private func processCustomChange() {
        guard !customText.isEmpty else { return }
        isCustomLoading = true
        processCustomInstruction(customText)
    }

    private func processOption(_ option: WritingOption) {
        loadingOptions.insert(option.id)
        appState.isProcessing = true

        Task {
            defer {
                loadingOptions.remove(option.id)
                appState.isProcessing = false
            }
            do {
                let result = try await appState.activeProvider.processText(
                    systemPrompt: option.systemPrompt,
                    userPrompt: appState.selectedText,
                    images: appState.selectedImages,
                    videos: appState.selectedVideos,
                    streaming: false
                )

                if [.summary, .keyPoints, .table].contains(option) {
                    await MainActor.run {
                        showResponseWindow(for: option, with: result)
                    }
                    closeAction()
                } else {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(result, forType: .string)

                    closeAction()

                    if let previousApp = appState.previousApplication {
                        previousApp.activate()

                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            simulatePaste()
                        }
                    }
                }
            } catch {
                print("Error processing text: \(error.localizedDescription)")
            }

            appState.isProcessing = false
        }
    }

    private func processCustomInstruction(_ instruction: String) {
        guard !instruction.isEmpty else { return }
        appState.isProcessing = true

        Task {
            do {
                let systemPrompt = """
                You are a writing and coding assistant. Your sole task is to respond to the user's instruction thoughtfully and comprehensively.
                If the instruction is a question, provide a detailed answer. But always return the best and most accurate answer and not different options.
                If it's a request for help, provide clear guidance and examples where appropriate. Make sure tu use the language used or specified by the user instruction.
                Use Markdown formatting to make your response more readable.
                """

                let userPrompt = appState.selectedText.isEmpty ?
                instruction :
                    """
                    User's instruction: \(instruction)

                    Text:
                    \(appState.selectedText)
                    """

                let result = try await appState.activeProvider.processText(
                    systemPrompt: systemPrompt,
                    userPrompt: userPrompt,
                    images: appState.selectedImages,
                    videos: appState.selectedVideos,
                    streaming: false
                )

                await MainActor.run {
                    let window = ResponseWindow(
                        title: "AI Response",
                        content: result,
                        selectedText: appState.selectedText.isEmpty ? instruction : appState.selectedText,
                        option: .proofread
                    )

                    WindowManager.shared.addResponseWindow(window)
                    window.makeKeyAndOrderFront(nil)
                    window.orderFrontRegardless()
                }

                closeAction()
            } catch {
                print("Error processing text: \(error.localizedDescription)")
            }

            isCustomLoading = false
            appState.isProcessing = false
        }
    }

    private func showResponseWindow(for option: WritingOption, with result: String) {
        DispatchQueue.main.async {
            let window = ResponseWindow(
                title: "\(option.rawValue) Result",
                content: result,
                selectedText: appState.selectedText,
                option: option
            )

            WindowManager.shared.addResponseWindow(window)

            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
        }
    }

    private func simulatePaste() {
        guard let source = CGEventSource(stateID: .hidSystemState) else { return }

        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
        keyDown?.flags = .maskCommand

        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
        keyUp?.flags = .maskCommand

        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
}
