import SwiftUI
import UniformTypeIdentifiers

/// The popup view that appears when the user invokes a keyboard shortcut. In normal mode it shows a text field and a grid of tool buttons,
/// and in edit mode it allows the user to reorder, edit, or delete any tool and add new ones.
struct PopupView: View {
    @ObservedObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme
    @StateObject private var commandsManager = CustomCommandsManager()
    let closeAction: () -> Void
    @AppStorage("use_gradient_theme") private var useGradientTheme = false
    @State private var customText: String = ""
    @State private var loadingOptions: Set<String> = []
    @State private var isCustomLoading: Bool = false
    
    // New state for managing tool ordering and edit mode.
    @State private var isEditMode: Bool = false
    @State private var toolItems: [ToolItem] = []
    @State private var showingToolEditor: ToolItem? = nil
    @State private var isAddingNewTool: Bool = false
    
    var body: some View {
        VStack(spacing: 16) {
            // Top bar: In normal mode, display a close button on the left and an edit (pencil) button on the right.
            // In edit mode, display a Reset button on the left and a Done button on the right.
            HStack {
                if isEditMode {
                    Button("Reset") {
                        toolItems = loadDefaultToolItems()
                    }
                    .buttonStyle(.plain)
                } else {
                    Button(action: closeAction) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 8)
                }
                
                Spacer()
                
                if isEditMode {
                    Button("Done") {
                        saveToolItems()
                        isEditMode = false
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 8)
                } else {
                    Button(action: { isEditMode = true }) {
                        Image(systemName: "pencil.circle.fill")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 8)
                }
            }
            .padding(.top, 8)
            
            // Text field for custom instructions.
            HStack(spacing: 8) {
                TextField(appState.selectedText.isEmpty ? "Describe your change..." : "Describe your change...", text: $customText)
                    .textFieldStyle(.plain)
                    .appleStyleTextField(text: customText, isLoading: isCustomLoading, onSubmit: processCustomInstruction)
            }
            .padding(.horizontal)
            
            // Only show the tools grid if there is some selected text or selected images.
            if !appState.selectedText.isEmpty || !appState.selectedImages.isEmpty {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                        ForEach(toolItems) { item in
                            ToolItemView(item: item, isEditMode: isEditMode,
                                         onSelect: {
                                handleToolSelection(item)
                            },
                                         onDelete: {
                                if let index = toolItems.firstIndex(of: item) {
                                    toolItems.remove(at: index)
                                    saveToolItems()
                                }
                            },
                                         onEdit: {
                                showingToolEditor = item
                            })
                            .onDrag {
                                return NSItemProvider(object: item.id as NSString)
                            }
                            .onDrop(of: [UTType.text], delegate: ToolDropDelegate(item: item, items: $toolItems))
                        }
                    }
                    .padding(.horizontal, 8)
                }
                .padding(.horizontal, 8)
            }
            
            // In edit mode, show an "Add New Tool" button at the bottom.
            if isEditMode {
                Button("Add New Tool") {
                    isAddingNewTool = true
                }
                .buttonStyle(.borderedProminent)
                .padding()
            }
        }
        .padding(.bottom, 8)
        .modifier(PopupBackgroundModifier(useGradientTheme: useGradientTheme))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.gray.opacity(0.2), lineWidth: 1)
        )
        .onAppear {
            // Load the persistent layout (or the default if none exists).
            if toolItems.isEmpty {
                toolItems = loadToolItems()
            }
        }
        .sheet(item: $showingToolEditor) { tool in
            CommandEditorView(toolItem: tool) { updatedCommand in
                if let index = toolItems.firstIndex(of: tool) {
                    toolItems[index] = ToolItem.from(customCommand: updatedCommand)
                }
            }
        }
        .sheet(isPresented: $isAddingNewTool) {
            CommandEditorView(toolItem: nil) { newCommand in
                toolItems.append(ToolItem.from(customCommand: newCommand))
            }
        }
    }
    
    // MARK: - Persistence of Tool Layout
    
    private let toolItemsKey = "toolItemsLayout"
    
    private func loadToolItems() -> [ToolItem] {
        if let data = UserDefaults.standard.data(forKey: toolItemsKey),
           let decoded = try? JSONDecoder().decode([ToolItem].self, from: data) {
            return decoded
        } else {
            return loadDefaultToolItems()
        }
    }
    
    private func saveToolItems() {
        if let data = try? JSONEncoder().encode(toolItems) {
            UserDefaults.standard.set(data, forKey: toolItemsKey)
        }
    }
    
    private func loadDefaultToolItems() -> [ToolItem] {
        var items: [ToolItem] = []
        for option in WritingOption.allCases {
            items.append(ToolItem.from(writingOption: option))
        }
        for command in commandsManager.commands {
            items.append(ToolItem.from(customCommand: command))
        }
        return items
    }
    
    // MARK: - Handling a Tool Selection
    
    private func handleToolSelection(_ item: ToolItem) {
        if isEditMode { return }
        // Depending on the type, process the selected tool.
        if item.type == .predefined, let raw = item.writingOptionRaw,
           let option = WritingOption.allCases.first(where: { $0.rawValue == raw }) {
            processOption(option)
        } else if item.type == .custom, let command = item.customCommand {
            processCustomCommand(command)
        }
        closeAction()
    }
    
    // MARK: - Existing Processing Functions (Unchanged)
    
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
        }
    }
    
    private func processCustomInstruction() {
        guard !customText.isEmpty else { return }
        isCustomLoading = true
        // Insert your custom instruction processing here.
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

// MARK: - Drag and Drop Delegate for Reordering
struct ToolDropDelegate: DropDelegate {
    let item: ToolItem
    @Binding var items: [ToolItem]
    
    func dropEntered(info: DropInfo) {
        guard let fromId = getDraggedItemId(info: info),
              let fromIndex = items.firstIndex(where: { $0.id == fromId }),
              let toIndex = items.firstIndex(of: item),
              fromIndex != toIndex else { return }
        
        withAnimation {
            items.move(fromOffsets: IndexSet(integer: fromIndex), toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex)
        }
    }
    
    func performDrop(info: DropInfo) -> Bool {
        return true
    }
    
    private func getDraggedItemId(info: DropInfo) -> String? {
        if let itemProvider = info.itemProviders(for: [UTType.text]).first {
            var draggedId: String?
            let semaphore = DispatchSemaphore(value: 0)
            itemProvider.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil) { (data, error) in
                if let data = data as? Data, let id = String(data: data, encoding: .utf8) {
                    draggedId = id
                }
                semaphore.signal()
            }
            semaphore.wait()
            return draggedId
        }
        return nil
    }
}
