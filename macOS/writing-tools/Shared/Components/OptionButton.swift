import SwiftUI

struct OptionButton: View {
    let option: WritingOption
    let action: () -> Void
    let isLoading: Bool

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: option.icon)
                Text(option.rawValue)
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
