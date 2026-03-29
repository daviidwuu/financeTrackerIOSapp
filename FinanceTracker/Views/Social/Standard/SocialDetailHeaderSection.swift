import SwiftUI

struct SocialHeaderPill<Content: View>: View {
    private let action: (() -> Void)?
    private let content: () -> Content
    
    init(action: (() -> Void)? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.action = action
        self.content = content
    }
    
    var body: some View {
        Group {
            if let action = action {
                Button(action: action) {
                    pillContent
                }
                .buttonStyle(.borderless)
            } else {
                pillContent
            }
        }
    }
    
    private var pillContent: some View {
        HStack(spacing: 4) {
            content()
        }
        .font(.subheadline)
        .fontWeight(.medium)
        .foregroundColor(.primary)
        .padding(.horizontal, AppSpacing.compact)
        .padding(.vertical, AppRadius.xSmall)
        .background(Color.primary.opacity(0.05))
        .clipShape(Capsule())
    }
}

struct SocialDetailHeaderSection<Avatar: View, Subtitle: View, ExtraActions: View>: View {
    let title: String
    let onBack: () -> Void
    var onMenu: (() -> Void)? = nil
    let avatar: () -> Avatar
    let subtitle: () -> Subtitle
    let onSettle: () -> Void
    let onAddExpense: () -> Void
    let extraActions: () -> ExtraActions
    
    init(
        title: String,
        onBack: @escaping () -> Void,
        onMenu: (() -> Void)? = nil,
        @ViewBuilder avatar: @escaping () -> Avatar,
        @ViewBuilder subtitle: @escaping () -> Subtitle,
        onSettle: @escaping () -> Void,
        onAddExpense: @escaping () -> Void,
        @ViewBuilder extraActions: @escaping () -> ExtraActions
    ) {
        self.title = title
        self.onBack = onBack
        self.onMenu = onMenu
        self.avatar = avatar
        self.subtitle = subtitle
        self.onSettle = onSettle
        self.onAddExpense = onAddExpense
        self.extraActions = extraActions
    }
    
    init(
        title: String,
        onBack: @escaping () -> Void,
        onMenu: (() -> Void)? = nil,
        @ViewBuilder avatar: @escaping () -> Avatar,
        @ViewBuilder subtitle: @escaping () -> Subtitle,
        onSettle: @escaping () -> Void,
        onAddExpense: @escaping () -> Void
    ) where ExtraActions == EmptyView {
        self.init(
            title: title,
            onBack: onBack,
            onMenu: onMenu,
            avatar: avatar,
            subtitle: subtitle,
            onSettle: onSettle,
            onAddExpense: onAddExpense,
            extraActions: { EmptyView() }
        )
    }
    
    var body: some View {
        Section {
            DetailHeaderView(
                title: title,
                onBack: onBack,
                onMenu: onMenu,
                backgroundColor: Color.backgroundPrimary,
                textColor: .primary,
                avatar: avatar,
                subtitle: subtitle,
                actions: { headerActions }
            )
        }
        .listRowInsets(EdgeInsets())
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }
    
    private var headerActions: some View {
        HStack(spacing: AppSpacing.compact) {
            Button(action: {
                HapticManager.shared.light()
                onSettle()
            }) {
                Text("Settle")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(Color.backgroundPrimary)
                    .padding(.horizontal, AppSpacing.margin)
                    .frame(height: 44)
                    .background(Color.primary)
                    .clipShape(Capsule())
            }
            .buttonStyle(.borderless)
            
            Button(action: {
                HapticManager.shared.light()
                onAddExpense()
            }) {
                Image(systemName: "plus")
                    .font(.headline)
                    .foregroundColor(Color.backgroundPrimary)
                    .frame(width: 44, height: 44)
                    .background(Color.primary)
                    .clipShape(Circle())
            }
            .buttonStyle(.borderless)
            
            extraActions()
        }
    }
}

