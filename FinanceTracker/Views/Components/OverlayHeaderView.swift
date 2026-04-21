import SwiftUI

// MARK: - Scroll Offset Tracking Infrastructure

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct ScrollOffsetTracker: View {
    var body: some View {
        GeometryReader { geometry in
            Color.clear
                .preference(
                    key: ScrollOffsetPreferenceKey.self,
                    value: -geometry.frame(in: .named("overlayHeaderScroll")).minY
                )
        }
        .frame(height: 0)
    }
}

// MARK: - Header Mode

enum OverlayHeaderMode {
    /// Centered title with back button. For settings/detail/sub-screens.
    case navigation(
        title: String,
        onBack: () -> Void,
        backIcon: String = "chevron.left",
        trailing: AnyView? = nil
    )

    /// Left-aligned large title with optional subtitle. For root/tab screens.
    case root(
        title: String,
        subtitle: String? = nil,
        trailing: AnyView? = nil,
        titleAccessory: AnyView? = nil,
        isWelcomeStyle: Bool = false
    )
}

// MARK: - Header View

struct OverlayHeaderView: View {
    let mode: OverlayHeaderMode
    let scrollOffset: CGFloat
    let fadeThreshold: CGFloat

    @Environment(\.colorScheme) var colorScheme

    init(mode: OverlayHeaderMode, scrollOffset: CGFloat = 0, fadeThreshold: CGFloat = 50) {
        self.mode = mode
        self.scrollOffset = scrollOffset
        self.fadeThreshold = fadeThreshold
    }

    // MARK: - Computed Properties

    private var backgroundOpacity: CGFloat {
        let progress = min(max(scrollOffset / fadeThreshold, 0), 1)
        return progress
    }

    private var backgroundView: some View {
        Color.backgroundPrimary
            .opacity(0.85 * backgroundOpacity)
            .background(
                Group {
                    if backgroundOpacity > 0 {
                        Rectangle()
                            .fill(.ultraThinMaterial)
                            .opacity(backgroundOpacity)
                    }
                }
            )
            .ignoresSafeArea(edges: .top)
    }

    // MARK: - Navigation Mode Header

    @ViewBuilder
    private func navigationHeader(title: String, onBack: @escaping () -> Void, backIcon: String, trailing: AnyView?) -> some View {
        HStack {
            // Back button
            Button(action: {
                HapticManager.shared.light()
                onBack()
            }) {
                Image(systemName: backIcon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                    .frame(width: AppSize.iconButton, height: AppSize.iconButton)
                    .background(Color.primary.opacity(0.05))
                    .clipShape(Circle())
            }

            Spacer()

            Text(title)
                .font(AppTypography.headline)
                .foregroundColor(.primary)

            Spacer()

            // Trailing action or invisible spacer for layout balance
            if let trailing = trailing {
                trailing
            } else {
                Color.clear
                    .frame(width: AppSize.iconButton, height: AppSize.iconButton)
            }
        }
        .padding(.horizontal, AppSpacing.margin + AppSpacing.compact)
        .padding(.top, 16)
    }

    // MARK: - Root Mode Header

    @ViewBuilder
    private func rootHeader(title: String, subtitle: String?, trailing: AnyView?, titleAccessory: AnyView?, isWelcomeStyle: Bool = false) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                if isWelcomeStyle {
                    // Small top text
                    Text(title)
                        .font(AppTypography.subheadline)
                        .foregroundColor(.secondary)
                    
                    // Big bottom text
                    HStack(spacing: 8) {
                        Text(subtitle ?? "")
                            .font(AppTypography.titleDisplay)
                            .foregroundColor(.primary)

                        if let titleAccessory = titleAccessory {
                            titleAccessory
                        }
                    }
                } else {
                    // Standard: Big top text
                    HStack(spacing: 8) {
                        Text(title)
                            .font(AppTypography.titleDisplay)
                            .foregroundColor(.primary)

                        if let titleAccessory = titleAccessory {
                            titleAccessory
                        }
                    }

                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(AppTypography.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            if let trailing = trailing {
                trailing
            }
        }
        .padding(.horizontal, AppSpacing.margin)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            switch mode {
            case .navigation(let title, let onBack, let backIcon, let trailing):
                navigationHeader(title: title, onBack: onBack, backIcon: backIcon, trailing: trailing)
            case .root(let title, let subtitle, let trailing, let titleAccessory, let isWelcomeStyle):
                rootHeader(title: title, subtitle: subtitle, trailing: trailing, titleAccessory: titleAccessory, isWelcomeStyle: isWelcomeStyle)
            }
        }
        .background(backgroundView)
    }
}

// MARK: - ViewModifier

struct OverlayHeaderModifier: ViewModifier {
    let mode: OverlayHeaderMode
    let fadeThreshold: CGFloat

    @State private var scrollOffset: CGFloat = 0

    init(mode: OverlayHeaderMode, fadeThreshold: CGFloat = 50) {
        self.mode = mode
        self.fadeThreshold = fadeThreshold
    }

    func body(content: Content) -> some View {
        ZStack(alignment: .top) {
            content
                .coordinateSpace(name: "overlayHeaderScroll")
                .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                    scrollOffset = value
                }

            OverlayHeaderView(
                mode: mode,
                scrollOffset: scrollOffset,
                fadeThreshold: fadeThreshold
            )
        }
    }
}

// MARK: - View Extension

extension View {
    func overlayHeader(
        _ mode: OverlayHeaderMode,
        fadeThreshold: CGFloat = 50
    ) -> some View {
        modifier(OverlayHeaderModifier(mode: mode, fadeThreshold: fadeThreshold))
    }
}

// MARK: - Previews

#Preview("Navigation Mode - Settings") {
    NavigationStack {
        ZStack {
            Color.backgroundPrimary.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    ScrollOffsetTracker()
                    Spacer().frame(height: 60)

                    ForEach(0..<20) { i in
                        Text("Settings Item \(i)")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Color.cardBackground)
                            .cornerRadius(AppRadius.medium)
                    }
                }
                .padding(.horizontal, AppSpacing.margin)
            }
        }
        .overlayHeader(.navigation(
            title: "Account Settings",
            onBack: { print("Back tapped") }
        ))
        .navigationBarBackButtonHidden(true)
    }
}

#Preview("Navigation Mode - with xmark") {
    NavigationStack {
        ZStack {
            Color.backgroundPrimary.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    ScrollOffsetTracker()
                    Spacer().frame(height: 60)

                    ForEach(0..<20) { i in
                        Text("Content Item \(i)")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Color.cardBackground)
                            .cornerRadius(AppRadius.medium)
                    }
                }
                .padding(.horizontal, AppSpacing.margin)
            }
        }
        .overlayHeader(.navigation(
            title: "Settings",
            onBack: { print("Close tapped") },
            backIcon: "xmark"
        ))
        .navigationBarBackButtonHidden(true)
    }
}

#Preview("Root Mode - Dashboard") {
    NavigationStack {
        ZStack {
            Color.backgroundPrimary.ignoresSafeArea()

            List {
                ScrollOffsetTracker()
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())

                Color.clear.frame(height: 80)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)

                ForEach(0..<30) { i in
                    Text("Dashboard Item \(i)")
                        .padding()
                }
                .listRowBackground(Color.cardBackground)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
        .overlayHeader(.root(
            title: "Social"
        ))
    }
}

#Preview("Root Mode - Simple") {
    NavigationStack {
        ZStack {
            Color.backgroundPrimary.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    ScrollOffsetTracker()
                    Spacer().frame(height: 80)

                    ForEach(0..<20) { i in
                        Text("Wallet Item \(i)")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Color.cardBackground)
                            .cornerRadius(AppRadius.medium)
                    }
                }
                .padding(.horizontal, AppSpacing.margin)
            }
        }
        .overlayHeader(.root(
            title: "Wallet",
            subtitle: nil
        ))
    }
}
