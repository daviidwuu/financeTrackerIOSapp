import SwiftUI

enum PremiumBadgeSize {
    case small
    case medium
}

enum PremiumBadgeType: String, CaseIterable, Identifiable {
    case king = "king"
    case pro = "pro"
    case saver = "saver"
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .king: return "king"
        case .pro: return "pro"
        case .saver: return "saver"
        }
    }
    
    var color: Color {
        switch self {
        case .king: return Color(hex: "#F5A623")
        case .pro: return Color.blue
        case .saver: return Color.green
        }
    }
}

struct PremiumBadge: View {
    let size: PremiumBadgeSize
    @AppStorage("premiumBadgeType") private var badgeType: PremiumBadgeType = .king
    
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
        Text(badgeType.title)
            .font(font)
            .foregroundColor(badgeType.color)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background(badgeType.color.opacity(0.15))
            .cornerRadius(cornerRadius)
    }
}
