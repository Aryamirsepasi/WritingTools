import SwiftUI

/// A card-style container view with an optional title and custom content.
public struct CardView<Content: View>: View {
    var title: String?
    var backgroundColor: Color
    var cornerRadius: CGFloat
    var shadowRadius: CGFloat
    var content: Content

    public init(title: String? = nil,
                backgroundColor: Color = .white,
                cornerRadius: CGFloat = 12,
                shadowRadius: CGFloat = 6,
                @ViewBuilder content: () -> Content) {
        self.title = title
        self.backgroundColor = backgroundColor
        self.cornerRadius = cornerRadius
        self.shadowRadius = shadowRadius
        self.content = content()
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title = title {
                Text(title)
                    .font(.headline)
                    .padding(.bottom, 4)
            }
            content
        }
        .padding()
        .background(backgroundColor)
        .cornerRadius(cornerRadius)
        .shadow(color: Color.black.opacity(0.1), radius: shadowRadius, x: 0, y: 2)
    }
} 