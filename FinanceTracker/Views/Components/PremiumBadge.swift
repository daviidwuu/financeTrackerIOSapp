import SwiftUI

enum PremiumBadgeSize {
    case small
    case medium
}

struct PremiumBadge: View {
    let size: PremiumBadgeSize
    
    private var font: Font {
        switch size {
        case .small:
            return .system(size: 12, weight: .bold, design: .rounded)
        case .medium:
            return .system(size: 14, weight: .bold, design: .rounded)
        }
    }
    
    private var horizontalPadding: CGFloat {
        switch size {
        case .small:
            return 10
        case .medium:
            return 14
        }
    }
    
    private var verticalPadding: CGFloat {
        switch size {
        case .small:
            return 4
        case .medium:
            return 6
        }
    }
    
    private var cornerRadius: CGFloat {
        switch size {
        case .small:
            return 10
        case .medium:
            return 12
        }
    }
    
    var body: some View {
        Text("king")
            .font(font)
            .foregroundColor(Color(hex: "#F5A623"))
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background(Color(hex: "#F5A623").opacity(0.15))
            .cornerRadius(cornerRadius)
    }
}
