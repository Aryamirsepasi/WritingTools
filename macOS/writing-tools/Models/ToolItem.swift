import Foundation

/// A tool that appears in the popup. It wraps a predefined writing tool (from WritingOption)
/// or a custom command.
struct ToolItem: Identifiable, Codable, Equatable {
    enum ToolType: String, Codable {
        case predefined
        case custom
    }
    
    var id: String
    var type: ToolType
    var writingOptionRaw: String? // used for predefined tools
    var customCommand: CustomCommand? // used for custom tools
    
    /// Creates a ToolItem from a predefined WritingOption.
    static func from(writingOption: WritingOption) -> ToolItem {
        return ToolItem(id: writingOption.id,
                        type: .predefined,
                        writingOptionRaw: writingOption.rawValue,
                        customCommand: nil)
    }
    
    /// Creates a ToolItem from a CustomCommand.
    static func from(customCommand: CustomCommand) -> ToolItem {
        return ToolItem(id: customCommand.id.uuidString,
                        type: .custom,
                        writingOptionRaw: nil,
                        customCommand: customCommand)
    }
} 