import SwiftUI

struct CircularProgressView: View {
    let progress: Double
    let lineWidth: CGFloat = 4
    var color: Color = .blue
    
    var body: some View {
        ZStack {
            // Background Circle
            Circle()
                .stroke(lineWidth: lineWidth)
                .opacity(0.3)
                .foregroundColor(color)
            
            // Foreground Circle
            Circle()
                .trim(from: 0.0, to: CGFloat(min(self.progress, 1.0)))
                .stroke(style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
                .foregroundColor(color)
                .rotationEffect(Angle(degrees: 270.0))
                .animation(.linear, value: progress)
        }
    }
}
