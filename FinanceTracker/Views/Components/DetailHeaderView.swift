import SwiftUI

struct DetailHeaderView<Content: View, Actions: View, Subtitle: View>: View {
    let title: String
    let onBack: () -> Void
    let backIcon: String
    let onMenu: (() -> Void)?
    let backgroundColor: Color
    let textColor: Color
    
    @ViewBuilder let avatar: () -> Content
    @ViewBuilder let subtitle: () -> Subtitle
    @ViewBuilder let actions: () -> Actions
    
    // Convenience init for String subtitle
    init(
        title: String,
        subtitle: String?,
        onBack: @escaping () -> Void,
        backIcon: String = "chevron.left",
        onMenu: (() -> Void)? = nil,
        backgroundColor: Color = .black,
        textColor: Color = .white,
        @ViewBuilder avatar: @escaping () -> Content,
        @ViewBuilder actions: @escaping () -> Actions
    ) where Subtitle == AnyView {
        self.title = title
        self.onBack = onBack
        self.backIcon = backIcon
        self.onMenu = onMenu
        self.backgroundColor = backgroundColor
        self.textColor = textColor
        self.avatar = avatar
        self.actions = actions
        self.subtitle = {
            if let subtitle = subtitle {
                AnyView(
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(textColor.opacity(0.9))
                )
            } else {
                AnyView(EmptyView())
            }
        }
    }
    
    // Full init
    init(
        title: String,
        onBack: @escaping () -> Void,
        backIcon: String = "chevron.left",
        onMenu: (() -> Void)? = nil,
        backgroundColor: Color = .black,
        textColor: Color = .white,
        @ViewBuilder avatar: @escaping () -> Content,
        @ViewBuilder subtitle: @escaping () -> Subtitle,
        @ViewBuilder actions: @escaping () -> Actions
    ) {
        self.title = title
        self.onBack = onBack
        self.backIcon = backIcon
        self.onMenu = onMenu
        self.backgroundColor = backgroundColor
        self.textColor = textColor
        self.avatar = avatar
        self.subtitle = subtitle
        self.actions = actions
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Background
            backgroundColor
                .overlay(backgroundColor == .black ? Color.black.opacity(0.2) : Color.clear)
                .ignoresSafeArea(edges: .top)
            
            // Top Navigation
            VStack {
                HStack {
                    Button(action: onBack) {
                        Image(systemName: backIcon)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(textColor)
                            .frame(width: 44, height: 44)
                            .background(textColor.opacity(0.05))
                            .clipShape(Circle())
                    }
                    
                    Spacer()
                    
                    if let onMenu = onMenu {
                        Button(action: onMenu) {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(textColor)
                                .frame(width: 44, height: 44)
                                .background(textColor.opacity(0.05))
                                .clipShape(Circle())
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.margin + AppSpacing.compact)
                .padding(.top, 16)
                
                Spacer()
            }
            // Removed hardcoded padding - rely on natural safe area placement if parent doesn't ignore it
            // or use safeAreaInset if needed. 
            // Since we want the header content to be IN the safe area, we don't apply padding here 
            // assuming the parent view respects safe area.
            
            VStack(spacing: 0) {
                Spacer()
                
                // Content
                VStack(spacing: 8) {
                    // Avatar
                    avatar()
                    
                    // Text
                    VStack(spacing: 4) {
                        Text(title)
                            .font(AppTypography.titleDisplay)
                            .foregroundColor(textColor)
                        
                        subtitle()
                    }
                    
                    // Actions
                    actions()
                        .padding(.horizontal, 24)
                }
                .padding(.bottom, 0)
            }
        }
        .frame(height: AppSize.headerHeight)
        // .mask(Rectangle()) // Removed mask to allow background extension
    }
}
