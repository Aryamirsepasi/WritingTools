import SwiftUI

/// A view that renders a tool button inside the popup using the unified button styles. 
/// When in edit mode, overlay buttons for editing and deletion are displayed.
struct ToolItemView: View {
    let item: ToolItem
    let isEditMode: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void
    let onEdit: () -> Void

    @ViewBuilder
    var toolButton: some View {
        if item.type == .predefined,
           let raw = item.writingOptionRaw,
           let option = WritingOption.allCases.first(where: { $0.rawValue == raw }) {
            OptionButton(option: option, action: isEditMode ? {} : onSelect, isLoading: false)
        } else if item.type == .custom,
                  let command = item.customCommand {
            CustomOptionButton(command: command, action: isEditMode ? {} : onSelect, isLoading: false)
        } else {
            EmptyView()
        }
    }

    var body: some View {
        ZStack {
            toolButton
            if isEditMode {
                VStack {
                    HStack {
                        Button(action: onEdit) {
                            Image(systemName: "pencil")
                                .foregroundColor(.blue)
                                .padding(4)
                        }
                        .buttonStyle(BorderlessButtonStyle())
                        Spacer()
                        Button(action: onDelete) {
                            Image(systemName: "minus.circle.fill")
                                .foregroundColor(.red)
                                .padding(4)
                        }
                        .buttonStyle(BorderlessButtonStyle())
                    }
                    Spacer()
                }
            }
        }
    }
}