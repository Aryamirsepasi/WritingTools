import SwiftUI

/// A simple editor view for creating or editing a tool (whether predefined or custom).
/// When saving, the updated ToolItem is returned via the onSave closure.
struct ToolEditorView: View {
    @Environment(\.dismiss) var dismiss
    var toolItem: ToolItem?
    var onSave: (ToolItem) -> Void
    
    @State private var name: String = ""
    @State private var prompt: String = ""
    @State private var selectedIcon: String = "star.fill"
    @State private var useResponseWindow: Bool = false
    
    init(toolItem: ToolItem?, onSave: @escaping (ToolItem) -> Void) {
        self.toolItem = toolItem
        self.onSave = onSave
        if let tool = toolItem {
            if tool.type == .predefined {
                _name = State(initialValue: tool.writingOptionRaw ?? "")
                if let option = WritingOption.allCases.first(where: { $0.rawValue == tool.writingOptionRaw }) {
                    _prompt = State(initialValue: option.systemPrompt)
                }
            } else {
                _name = State(initialValue: tool.customCommand?.name ?? "")
                _prompt = State(initialValue: tool.customCommand?.prompt ?? "")
                _selectedIcon = State(initialValue: tool.customCommand?.icon ?? "star.fill")
                _useResponseWindow = State(initialValue: tool.customCommand?.useResponseWindow ?? false)
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text(toolItem == nil ? "New Tool" : "Edit Tool")
                    .font(.headline)
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            
            Form {
                Section(header: Text("Tool Details")) {
                    TextField("Name", text: $name)
                    TextEditor(text: $prompt)
                        .frame(height: 150)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                    HStack {
                        Text("Icon:")
                        Button(action: {}) {
                            Image(systemName: selectedIcon)
                                .font(.title2)
                        }
                        .buttonStyle(.plain)
                        // For demonstration, tapping cycles through some sample icons.
                        .onTapGesture {
                            let icons = ["star.fill", "pencil", "textformat.abc"]
                            if let index = icons.firstIndex(of: selectedIcon) {
                                selectedIcon = icons[(index + 1) % icons.count]
                            }
                        }
                    }
                    Toggle("Show Response in Window", isOn: $useResponseWindow)
                }
            }
            
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.escape, modifiers: [])
                
                Spacer()
                
                Button("Save") {
                    let newTool: ToolItem
                    if let tool = toolItem, tool.type == .custom {
                        let command = CustomCommand(id: tool.customCommand?.id ?? UUID(),
                                                    name: name,
                                                    prompt: prompt,
                                                    icon: selectedIcon,
                                                    useResponseWindow: useResponseWindow)
                        newTool = ToolItem.from(customCommand: command)
                    } else {
                        // For predefined tools, saving creates a custom override.
                        let command = CustomCommand(id: UUID(),
                                                    name: name,
                                                    prompt: prompt,
                                                    icon: selectedIcon,
                                                    useResponseWindow: useResponseWindow)
                        newTool = ToolItem(id: UUID().uuidString,
                                           type: .custom,
                                           writingOptionRaw: nil,
                                           customCommand: command)
                    }
                    onSave(newTool)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.isEmpty || prompt.isEmpty)
            }
            .padding()
        }
        .frame(width: 500, height: 600)
    }
} 