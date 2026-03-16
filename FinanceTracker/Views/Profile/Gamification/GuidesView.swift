import SwiftUI

// MARK: - Guides List View
struct GuidesListView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @State private var selectedGuide: GuideTutorial?
    
    // Guide Data using TutorialStep format
    struct GuideTutorial: Identifiable, Hashable {
        let id = UUID()
        let title: String
        let icon: String
        let color: Color
        let tutorialSteps: [TutorialStep]
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
        static func == (lhs: GuideTutorial, rhs: GuideTutorial) -> Bool {
            lhs.id == rhs.id
        }
    }
    
    let guides: [GuideTutorial] = [
        GuideTutorial(
            title: "Homescreen & Lockscreen Widget",
            icon: "square.stack.3d.up.fill",
            color: .blue,
            tutorialSteps: [
                TutorialStep(icon: "hand.tap.fill", iconColor: .blue, title: "Go to Your Home Screen", description: "Navigate to your iPhone Home Screen or Lock Screen. Find an empty space to start.", animationType: .bounce),
                TutorialStep(icon: "hand.draw.fill", iconColor: .purple, title: "Long Press", description: "Long press on an empty area until the apps start jiggling and you enter edit mode.", animationType: .pulse),
                TutorialStep(icon: "plus.circle.fill", iconColor: Color(hex: "#34C759"), title: "Tap the + Button", description: "Look for the '+' button in the top-left corner. Tap it to open the widget gallery.", animationType: .bounce),
                TutorialStep(icon: "magnifyingglass", iconColor: .orange, title: "Search for 'wym'", description: "In the widget gallery search bar, type 'wym' to find the app's widgets.", animationType: .float),
                TutorialStep(icon: "square.grid.2x2.fill", iconColor: .blue, title: "Select Your Widget", description: "Choose your preferred widget size — small, medium, or large. Tap 'Add Widget' to place it.", animationType: .rotate),
                TutorialStep(icon: "checkmark.circle.fill", iconColor: Color(hex: "#34C759"), title: "Position & Done", description: "Drag your widget to the perfect position on your screen, then tap 'Done'. Your finances are now always one glance away!", animationType: .pulse)
            ]
        ),
        GuideTutorial(
            title: "Shortcut & Back Tap",
            icon: "hand.tap.fill",
            color: .purple,
            tutorialSteps: [
                TutorialStep(icon: "gear", iconColor: .gray, title: "Open iPhone Settings", description: "Start by opening the Settings app on your iPhone. We'll set up a quick shortcut to log expenses.", animationType: .rotate),
                TutorialStep(icon: "hand.raised.fill", iconColor: .blue, title: "Navigate to Accessibility", description: "Go to Settings → Accessibility → Touch. Scroll down to find the 'Back Tap' option.", animationType: .bounce),
                TutorialStep(icon: "hand.tap.fill", iconColor: .purple, title: "Choose Double or Triple Tap", description: "Select either 'Double Tap' or 'Triple Tap'. Double tap is quicker; triple tap avoids accidental triggers.", animationType: .pulse),
                TutorialStep(icon: "arrow.down.to.line", iconColor: .orange, title: "Find the Shortcut", description: "Scroll down in the action list to the 'Shortcuts' section. Select the 'wym' shortcut to log transactions.", animationType: .float),
                TutorialStep(icon: "bolt.fill", iconColor: .yellow, title: "You're All Set!", description: "Now just tap the back of your iPhone to instantly open the transaction logger. The fastest way to track your spending!", animationType: .bounce)
            ]
        ),
        GuideTutorial(
            title: "Splitting Bills",
            icon: "person.2.fill",
            color: .green,
            tutorialSteps: [
                TutorialStep(icon: "plus.circle.fill", iconColor: .blue, title: "Add a Transaction", description: "Start by adding a new transaction as you normally would. Enter the total bill amount.", animationType: .bounce),
                TutorialStep(icon: "person.2.fill", iconColor: .green, title: "Tap 'Split'", description: "Before saving, look for the 'Split' button. Tap it to enter split mode and choose who to split with.", animationType: .pulse),
                TutorialStep(icon: "person.crop.circle.badge.plus", iconColor: .purple, title: "Select Friends", description: "Choose the friends you want to split with. You can select multiple people from your friends list or add guests.", animationType: .float),
                TutorialStep(icon: "slider.horizontal.3", iconColor: .orange, title: "Choose Split Type", description: "Pick how to divide: Equal (same for everyone), Exact (specific amounts), or Percentage (custom percentages).", animationType: .rotate),
                TutorialStep(icon: "bell.badge.fill", iconColor: .red, title: "Track Payments", description: "Save the transaction. Your friends get notified and you can track who has paid back in the Social tab!", animationType: .bounce)
            ]
        )
    ]
    
    var body: some View {
        ZStack {
            Color.backgroundPrimary
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    ScrollOffsetTracker()
                    Spacer().frame(height: 60)
                    
                    MenuSection {
                        ForEach(guides.indices, id: \.self) { index in
                            let guide = guides[index]
                            Button(action: { HapticManager.shared.light(); 
                                selectedGuide = guide
                            }) {
                                HStack(spacing: 16) {
                                    Image(systemName: guide.icon)
                                        .font(.title2)
                                        .foregroundColor(.white)
                                        .frame(width: 40, height: 40)
                                        .background(guide.color)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                    
                                    Text(guide.title)
                                        .font(.body)
                                        .foregroundColor(.primary)
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(Color(UIColor.tertiaryLabel))
                                }
                                .padding(.vertical, 12)
                                .padding(.horizontal, 16)
                                .contentShape(Rectangle())
                            }
                            
                            
                            if index < guides.count - 1 {
                                MenuDivider()
                            }
                        }
                    }
                    .padding(.top, 0)
                    
                    Spacer()
                }
                .padding(.top, 20)
            }
        }
        .overlayHeader(.navigation(title: "Guides", onBack: { dismiss() }))
        .navigationBarBackButtonHidden(true)
        .fullScreenCover(item: $selectedGuide) { guide in
            TutorialView(
                title: guide.title,
                steps: guide.tutorialSteps,
                accentColor: guide.color
            )
        }
    }
}

#Preview {
    NavigationView {
        GuidesListView()
    }
}
