import SwiftUI

struct CustomCommandsView: View {
    @ObservedObject var commandsManager: CustomCommandsManager
    @Environment(\.dismiss) var dismiss
    @State private var isAddingNew = false
    @State private var selectedCommand: CustomCommand?
    @State private var editingCommand: CustomCommand?
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Custom Commands")
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
            
            List {
                ForEach(commandsManager.commands) { command in
                    CustomCommandRow(
                        command: command,
                        onEdit: { editingCommand = $0 },
                        onDelete: { commandsManager.deleteCommand($0) }
                    )
                }
            }
            
            Divider()
            
            HStack {
                Button(action: { isAddingNew = true }) {
                    Label("Add Custom Command", systemImage: "plus.circle.fill")
                        .font(.body)
                }
                .controlSize(.large)
                .padding()
                
                Spacer()
            }
        }
        .frame(width: 500, height: 400)
        .background(Color(.windowBackgroundColor))
        .sheet(isPresented: $isAddingNew) {
            CommandEditorView(toolItem: nil) { newCommand in
                commandsManager.addCommand(newCommand)
                isAddingNew = false
            }
        }
        .sheet(item: $editingCommand) { command in
            // Wrap the CustomCommand into a ToolItem to conform with the editor’s initializer.
            CommandEditorView(toolItem: ToolItem.from(customCommand: command)) { updatedCommand in
                commandsManager.updateCommand(updatedCommand)
                editingCommand = nil
            }
        }
    }
}

struct CustomCommandRow: View {
    let command: CustomCommand
    var onEdit: (CustomCommand) -> Void
    var onDelete: (CustomCommand) -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: command.icon)
                .font(.title2)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(command.name)
                    .font(.headline)
                Text(command.prompt)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            Spacer()
            
            Button(action: { onEdit(command) }) {
                Image(systemName: "pencil")
                    .font(.title2)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 4)
            
            Button(action: { onDelete(command) }) {
                Image(systemName: "trash")
                    .font(.title2)
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 4)
        }
        .padding(.vertical, 8)
    }
}

struct CommandEditorView: View {
    @Environment(\.dismiss) var dismiss
    var toolItem: ToolItem?
    var onSave: (CustomCommand) -> Void
    
    @State private var name: String = ""
    @State private var prompt: String = ""
    @State private var selectedIcon: String = "star.fill"
    @State private var useResponseWindow: Bool = false
    @State private var showingIconPicker = false
    
    init(toolItem: ToolItem?, onSave: @escaping (CustomCommand) -> Void) {
        self.toolItem = toolItem
        self.onSave = onSave
        if let tool = toolItem {
            if tool.type == .predefined {
                _name = State(initialValue: tool.writingOptionRaw ?? "")
                if let option = WritingOption.allCases.first(where: { $0.rawValue == tool.writingOptionRaw }) {
                    _prompt = State(initialValue: option.systemPrompt)
                }
            } else {
                let command = tool.customCommand
                _name = State(initialValue: command?.name ?? "")
                _prompt = State(initialValue: command?.prompt ?? "")
                _selectedIcon = State(initialValue: command?.icon ?? "star.fill")
                _useResponseWindow = State(initialValue: command?.useResponseWindow ?? false)
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(toolItem == nil ? "New Command" : "Edit Command")
                    .font(.headline)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            
            // Form content
            ScrollView {
                VStack(spacing: 20) {
                    HStack(alignment: .top, spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Name")
                                .font(.headline)
                            TextField("Command Name", text: $name)
                                .textFieldStyle(.roundedBorder)
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Icon")
                                .font(.headline)
                            Button {
                                showingIconPicker = true
                            } label: {
                                HStack {
                                    Image(systemName: selectedIcon)
                                        .font(.title2)
                                        .foregroundColor(.accentColor)
                                    Text("Change Icon")
                                        .foregroundColor(.accentColor)
                                }
                                .padding(8)
                                .background(Color(.controlBackgroundColor))
                                .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Prompt")
                            .font(.headline)
                        TextEditor(text: $prompt)
                            .frame(height: 150)
                            .padding(4)
                            .background(Color(.textBackgroundColor))
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                            )
                    }
                    Toggle("Show Response in Chat Window", isOn: $useResponseWindow)
                        .padding(.horizontal)
                    Text("When enabled, responses will appear in a chat window instead of replacing the selected text.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                }
                .padding()
            }
            
            Divider()
            
            // Footer with Cancel and Save buttons
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.escape, modifiers: [])
                
                Spacer()
                
                Button("Save") {
                    let command = CustomCommand(
                        id: toolItem?.customCommand?.id ?? UUID(),
                        name: name,
                        prompt: prompt,
                        icon: selectedIcon,
                        useResponseWindow: useResponseWindow
                    )
                    onSave(command)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.isEmpty || prompt.isEmpty)
                .padding()
            }
            .padding()
        }
        .frame(width: 500, height: 600)
        .background(Color(.windowBackgroundColor))
        .sheet(isPresented: $showingIconPicker) {
            IconPickerView(selectedIcon: $selectedIcon)
        }
    }
}
