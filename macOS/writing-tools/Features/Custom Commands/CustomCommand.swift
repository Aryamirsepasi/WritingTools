import Foundation

struct CustomCommand: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var prompt: String
    var icon: String
    var useResponseWindow: Bool

    init(id: UUID = UUID(), name: String, prompt: String, icon: String, useResponseWindow: Bool = false) {
        self.id = id
        self.name = name
        self.prompt = prompt
        self.icon = icon
        self.useResponseWindow = useResponseWindow
    }
}
