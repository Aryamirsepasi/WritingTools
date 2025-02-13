import SwiftUI

struct LinkText: View {
    var body: some View {
        HStack(spacing: 4) {
            Text("Local LLMs: use the instructions on")
                .font(.caption)
                .foregroundColor(.secondary)

            Text("GitHub Page")
                .font(.caption)
                .foregroundColor(.blue)
                .underline()
                .onTapGesture {
                    NSWorkspace.shared.open(URL(string: "https://github.com/theJayTea/WritingTools?tab=readme-ov-file#-optional-ollama-local-llm-instructions")!)
                }

            Text(".")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}
