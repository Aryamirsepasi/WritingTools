import SwiftUI

struct CustomOptionButton: View {
    let command: CustomCommand
    let action: () -> Void
    let isLoading: Bool

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: command.icon)
                Text(command.name)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: 140)
            .padding()
            .background(Color(.controlBackgroundColor))
            .cornerRadius(8)
        }
        .buttonStyle(LoadingButtonStyle(isLoading: isLoading))
        .disabled(isLoading)
    }
}
