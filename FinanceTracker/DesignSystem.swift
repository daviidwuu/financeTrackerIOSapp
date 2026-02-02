import SwiftUI

struct AppRadius {
    static let large: CGFloat = 28
    static let medium: CGFloat = 16
    static let small: CGFloat = 12
    static let button: CGFloat = 25
}

struct AppTypography {
    static func heroRounded(size: CGFloat) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }
    
    /// Scale for hero inputs (Add Transaction amount)
    static let heroInput = heroRounded(size: 64)
    
    /// Scale for prominent balances (Dashboard)
    static let prominentBalance = heroRounded(size: 42)
    
    /// Scale for section headings
    static let sectionHeader = heroRounded(size: 28)
    
    /// Scale for username and secondary titles
    static let titleDisplay = heroRounded(size: 34)
}

struct AppSpacing {
    /// Standard horizontal margin for the whole app
    static let margin: CGFloat = 20
    
    /// Spacing between major sections
    static let section: CGFloat = 32
    
    /// Spacing between elements within a section
    static let element: CGFloat = 16
    
    /// Spacing for tight groupings
    static let compact: CGFloat = 8
}

extension View {
    func appCardStyle(radius: CGFloat = AppRadius.medium, color: Color = .cardBackground) -> some View {
        self
            .padding()
            .background(color)
            .cornerRadius(radius)
    }
}

struct AppConstants {
    // MARK: - Icons
    /// A comprehensive list of SF Symbols for categories, budgets, and goals
    static let allIcons: [String] = [
        // Essentials & Living
        "house.fill", "house.lodge.fill", "key.fill", "bed.double.fill", "building.columns.fill",
        "drop.fill", "bolt.fill", "flame.fill", "wifi", "phone.fill", "trash.fill",
        
        // Food & Drink
        "fork.knife", "cart.fill", "takeoutbag.and.cup.and.straw.fill", "cup.and.saucer.fill",
        "wineglass.fill", "birthday.cake.fill", "carrot.fill", "fish.fill",
        
        // Transport
        "car.fill", "bus.fill", "tram.fill", "airplane", "fuelpump.fill",
        "bicycle", "figure.walk", "map.fill", "ticket.fill",
        
        // Shopping & Personal
        "bag.fill", "tshirt.fill", "eyeglasses", "tag.fill", "gift.fill",
        "cart.badge.plus", "wand.and.stars", "scissors", "clock.fill",
        
        // Finance & Work
        "dollarsign.circle.fill", "creditcard.fill", "banknote.fill", "briefcase.fill",
        "case.fill", "doc.text.fill", "chart.pie.fill", "chart.line.uptrend.xyaxis",
        "building.2.fill", "laptopcomputer", "printer.fill",
        
        // Entertainment & Leisure
        "tv.fill", "gamecontroller.fill", "headphones", "music.note", "film.fill",
        "theatermasks.fill", "book.fill", "photo.fill",
        "puzzlepiece.fill", "party.popper.fill", "balloon.2.fill",
        
        // Health & Wellness
        "heart.fill", "pills.fill", "cross.case.fill", "stethoscope", "staroflife.fill",
        "brain.head.profile", "dumbbell.fill", "figure.run", "sportscourt.fill",
        "soccerball", "tennis.racket",
        
        // Education & Self-Improvement
        "graduationcap.fill", "book.closed.fill", "pencil", "paintbrush.fill",
        "hammer.fill", "wrench.and.screwdriver.fill", "lightbulb.fill",
        
        // Tech & Digital
        "iphone", "desktopcomputer", "keyboard", "magicmouse.fill", "cable.connector",
        "cloud.fill", "lock.fill", "shield.fill",
        
        // Nature & Pets
        "leaf.fill", "pawprint.fill", "tree.fill", "sun.max.fill", "moon.fill",
        
        // Misc
        "star.fill", "suit.heart.fill", "hand.thumbsup.fill", "flag.fill", "bell.fill",
        "location.fill", "calendar", "bubble.left.and.bubble.right.fill", "lifepreserver.fill"
    ]
    
    // MARK: - Colors
    /// A wide palette of colors for categories, using system and custom hues
    static let allColors: [Color] = [
        // Reds (Passion/Urgency)
        Color(hex: "#FF3B30"), // System Red
        Color(hex: "#FF2D55"), // System Pink
        Color(hex: "#E0245E"), // Deep Pink
        Color(hex: "#D0021B"), // Deep Red
        
        // Oranges (Energy)
        Color(hex: "#FF9500"), // System Orange
        Color(hex: "#FF7F00"), // Dark Orange
        Color(hex: "#F5A623"), // Gold
        
        // Yellows (Optimism)
        Color(hex: "#FFCC00"), // System Yellow
        Color(hex: "#FFD60A"), // Bright Yellow
        
        // Greens (Growth/Money)
        Color(hex: "#34C759"), // System Green
        Color(hex: "#28CD41"), // Bright Green
        Color(hex: "#4CD964"), // Light Green
        Color(hex: "#00C7BE"), // Teal/Aqua
        
        // Blues (Trust/Calm)
        Color(hex: "#5AC8FA"), // Light Blue
        Color(hex: "#007AFF"), // System Blue
        Color(hex: "#1DA1F2"), // Twitter Blue
        Color(hex: "#0040DD"), // Dark Blue
        
        // Purples (Creativity/Luxury)
        Color(hex: "#5856D6"), // System Indigo
        Color(hex: "#AF52DE"), // System Purple
        Color(hex: "#794BC4"), // Vivid Purple
        
        // Grayscale (Neutral/Professional)
        Color(hex: "#000000"), // Black
        Color(hex: "#3A3A3C"), // Dark Gray
        Color(hex: "#8E8E93"), // System Gray
        Color(hex: "#C7C7CC"), // Light Gray
        Color(hex: "#E5E5EA"), // Very Light Gray
        .white                 // White
    ]
}
