import SwiftUI

struct GroupAvatar: View {
    let icon: String
    let color: String
    let size: CGFloat
    
    var gradient: LinearGradient {
        Color.GradientTheme.gradient(for: color)
    }
    
    var body: some View {
        ZStack {
            Circle()
                .fill(gradient)
                .frame(width: size, height: size)
                .shadow(color: Color(hex: color).opacity(0.3), radius: size * 0.1, x: 0, y: size * 0.05)
            
            Image(systemName: icon)
                .font(.system(size: size * 0.4, weight: .semibold))
                .foregroundColor(.white)
        }
    }
}
