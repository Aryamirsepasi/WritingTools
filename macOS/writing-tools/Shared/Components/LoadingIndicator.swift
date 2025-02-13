import SwiftUI

/// A circular loading indicator with customizable color, size, line width, and animation duration.
public struct LoadingIndicator: View {
    var size: CGFloat
    var lineWidth: CGFloat
    var color: Color
    var animationDuration: Double

    @State private var isAnimating = false

    public init(size: CGFloat = 50,
                lineWidth: CGFloat = 4,
                color: Color = .blue,
                animationDuration: Double = 1) {
        self.size = size
        self.lineWidth = lineWidth
        self.color = color
        self.animationDuration = animationDuration
    }
    
    public var body: some View {
        Circle()
            .trim(from: 0, to: 0.7)
            .stroke(style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            .foregroundColor(color)
            .frame(width: size, height: size)
            .rotationEffect(Angle(degrees: isAnimating ? 360 : 0))
            .animation(Animation.linear(duration: animationDuration).repeatForever(autoreverses: false), value: isAnimating)
            .onAppear {
                isAnimating = true
            }
    }
} 