import SwiftUI
import AppIntents

struct ShortcutsView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.scenePhase) var scenePhase
    @State private var showSetupGuide = false
    @State private var didOpenShortcuts = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                Color.backgroundPrimary.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        ScrollOffsetTracker()
                        Spacer().frame(height: 80)

                        // Hero Header Matching ProfileView Theme
                        VStack(spacing: 12) {
                            // Avatar Substitute
                            Circle()
                                .fill(Color.orange.opacity(0.1))
                                .frame(width: 86, height: 86)
                                .overlay(
                                    Image(systemName: "bolt.fill")
                                        .font(.system(size: 36, weight: .bold))
                                        .foregroundColor(.orange)
                                )
                                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                            
                            // Text Info
                            VStack(spacing: 4) {
                                Text("Shortcuts")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.primary)
                                
                                Text("Log transactions instantly")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.top, 4)
                        
                        ShortcutsLink()
                            .shortcutsLinkStyle(.automaticOutline)
                            .padding(.top, 4)
                            .simultaneousGesture(TapGesture().onEnded {
                                didOpenShortcuts = true
                            })

                        // Standard Components
                        VStack(spacing: AppSpacing.margin) {
                            MenuSection("Features") {
                                MenuControlRow(
                                    icon: "clock.arrow.2.circlepath",
                                    title: "Automate",
                                    subtitle: "Trigger by time, location, or opening an app."
                                ) { EmptyView() }
                                MenuDivider()
                                
                                MenuControlRow(
                                    icon: "hand.tap.fill",
                                    title: "Back Tap",
                                    subtitle: "Double tap the back of your phone to log."
                                ) { EmptyView() }
                            }
                            
                            MenuSection("Configuration") {
                                Button {
                                    HapticManager.shared.light()
                                    showSetupGuide = true
                                } label: {
                                    MenuRowView(
                                        icon: "list.bullet.rectangle.portrait.fill",
                                        title: "Setup Guide",
                                        value: "Step-by-step",
                                        showChevron: true
                                    )
                                }
                            }
                        }
                        .padding(.bottom, 40)
                    }
                }
                .scrollContentBackground(.hidden)
                .scrollIndicators(.hidden)
            }
            .overlayHeader(.navigation(title: "Shortcuts", onBack: { dismiss() })) // Standard App Header
            .navigationBarHidden(true)
            .sheet(isPresented: $showSetupGuide) {
                ShortcutSetupGuideView()
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active && didOpenShortcuts {
                    didOpenShortcuts = false
                    showSetupGuide = true
                }
            }
        }
    }
}

// MARK: - Setup Guide Sheet

struct ShortcutSetupGuideView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.backgroundPrimary.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: AppSpacing.margin) {
                        ScrollOffsetTracker()
                        Spacer().frame(height: 60)

                        MenuSection("Automations") {
                            stepsView(steps: [
                                "Open the Shortcuts app",
                                "Tap the Automation tab at the bottom",
                                "Tap + → New Automation",
                                "Choose a trigger (e.g. Time of Day)",
                                "Tap New Blank Automation",
                                "Search for and add 'Log Transaction'",
                                "Turn off 'Ask Before Running'"
                            ])
                        }

                        MenuSection("Back Tap") {
                            stepsView(steps: [
                                "Open Settings",
                                "Go to Accessibility → Touch → Back Tap",
                                "Tap Double Tap or Triple Tap",
                                "Scroll down to the Shortcuts section",
                                "Select Log Transaction"
                            ])
                            MenuDivider()
                            Button {
                                HapticManager.shared.light()
                                // Try deep-linking to Accessibility Settings, fallback to general Settings if needed
                                if let url = URL(string: "App-Prefs:root=ACCESSIBILITY") {
                                    UIApplication.shared.open(url)
                                } else if let url = URL(string: UIApplication.openSettingsURLString) {
                                    UIApplication.shared.open(url)
                                }
                            } label: {
                                MenuControlRow(
                                    title: "Accessibility Settings",
                                    subtitle: nil
                                ) {
                                    Image(systemName: "arrow.up.right.square")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(Color(UIColor.tertiaryLabel))
                                }
                            }
                            .buttonStyle(MenuRowButtonStyle())
                        }
                    }
                    .padding(.bottom, 40)
                }
                .scrollContentBackground(.hidden)
                .scrollIndicators(.hidden)
            }
            .overlayHeader(.navigation(title: "Setup Guide", onBack: { dismiss() }, backIcon: "xmark"))
            .navigationBarHidden(true)
        }
    }

    @ViewBuilder
    private func stepsView(steps: [String]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                // Utilize the standard profile/setting menu row style for steps!
                MenuControlRow(
                    icon: "\(index + 1).circle.fill",
                    title: step,
                    subtitle: nil
                ) {
                    EmptyView()
                }
                
                if index != steps.count - 1 {
                    MenuDivider()
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        ShortcutsView()
            .environmentObject(AppState.shared)
    }
}
