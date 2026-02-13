import SwiftUI
import AVKit

// MARK: - Models
struct Guide: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let icon: String
    let color: Color
    let steps: [GuideStep]
    let videoPlaceholder: String // System Image name for now
}

struct GuideStep: Identifiable, Hashable {
    let id = UUID()
    let number: Int
    let text: String
    let isBold: Bool // For emphasized steps
}

// MARK: - Guides List View
// MARK: - Guides List View
struct GuidesListView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @State private var selectedGuide: Guide?
    
    // Guide Data
    let guides: [Guide] = [
        Guide(
            title: "Homescreen & Lockscreen Widget",
            icon: "square.stack.3d.up.fill",
            color: .blue,
            steps: [
                GuideStep(number: 1, text: "Go to your Home Screen or Lock Screen.", isBold: false),
                GuideStep(number: 2, text: "Long press on an empty space until apps jiggle.", isBold: true),
                GuideStep(number: 3, text: "Tap the + button in the top left corner.", isBold: true),
                GuideStep(number: 4, text: "Search for 'wym' in the widget gallery.", isBold: true),
                GuideStep(number: 5, text: "Select your preferred widget and tap 'Add Widget'.", isBold: true),
                GuideStep(number: 6, text: "Drag to position it, then tap Done.", isBold: false)
            ],
            videoPlaceholder: "apps.iphone"
        ),
        Guide(
            title: "Shortcut & Back Tap",
            icon: "hand.tap.fill",
            color: .purple,
            steps: [
                GuideStep(number: 1, text: "First, ensure you have the 'wym' shortcut enabled.", isBold: false),
                GuideStep(number: 2, text: "Open iPhone Settings.", isBold: true),
                GuideStep(number: 3, text: "Go to Accessibility > Touch.", isBold: true),
                GuideStep(number: 4, text: "Scroll down and select 'Back Tap'.", isBold: true),
                GuideStep(number: 5, text: "Choose 'Double Tap' or 'Triple Tap'.", isBold: true),
                GuideStep(number: 6, text: "Scroll down to Shortcuts and select 'wym'.", isBold: true),
                GuideStep(number: 7, text: "Now just tap the back of your phone to log expenses!", isBold: false)
            ],
            videoPlaceholder: "hand.point.up.left.fill"
        ),
        Guide(
            title: "Splitting Bills",
            icon: "person.2.fill",
            color: .green,
            steps: [
                GuideStep(number: 1, text: "When adding a transaction, tap 'Split'.", isBold: true),
                GuideStep(number: 2, text: "Select friends to split with.", isBold: true),
                GuideStep(number: 3, text: "Choose split type: Equal, Exact, or Percentage.", isBold: true),
                GuideStep(number: 4, text: "Save the transaction.", isBold: false),
                GuideStep(number: 5, text: "Track who owes you in the Friends tab.", isBold: false)
            ],
            videoPlaceholder: "banknote.fill"
        )
    ]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                MenuSection {
                    ForEach(guides.indices, id: \.self) { index in
                        let guide = guides[index]
                        Button(action: {
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
                        .buttonStyle(.plain)
                        
                        if index < guides.count - 1 {
                            MenuDivider()
                        }
                    }
                }
                
                Spacer()
            }
            .padding(.top, 20)
        }
        .background(Color(UIColor.systemBackground))
        .navigationTitle("Guides")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedGuide) { guide in
            GuideDetailView(guide: guide)
        }
    }
}

// MARK: - Guide Detail View
struct GuideDetailView: View {
    let guide: Guide
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            Color(UIColor.systemBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header (Video Area Placeholder)
                ZStack {
                    Rectangle()
                        .fill(guide.color.opacity(0.1))
                    
                    // Simulated Animation/Video
                    Image(systemName: guide.videoPlaceholder)
                        .font(.system(size: 80))
                        .foregroundColor(guide.color)
                        .scaleEffect(isAnimating ? 1.1 : 1.0)
                        .rotationEffect(Angle(degrees: isAnimating ? 5 : -5))
                        .animation(Animation.easeInOut(duration: 2).repeatForever(autoreverses: true), value: isAnimating)
                }
                .frame(height: UIScreen.main.bounds.height * 0.25)
                .overlay(
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundColor(.secondary)
                            .padding()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                )
                
                // Content
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        Text(guide.title)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .padding(.top)
                        
                        VStack(alignment: .leading, spacing: 20) {
                            ForEach(guide.steps) { step in
                                HStack(alignment: .top, spacing: 16) {
                                    Text("\(step.number)")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .frame(width: 30, height: 30)
                                        .background(Circle().fill(guide.color))
                                    
                                    Text(step.text)
                                        .font(step.isBold ? .headline : .body)
                                        .foregroundColor(step.isBold ? .primary : .secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }
                    .padding(24)
                }
                
                // Footer
                VStack {
                    Button(action: {
                        dismiss()
                    }) {
                        Text("Got it!")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(guide.color)
                            .clipShape(Capsule()) // Standard button shape
                    }
                    .padding()
                }
                .background(
                    Color(UIColor.systemBackground)
                        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: -5)
                )
            }
        }
        .onAppear {
            isAnimating = true
        }
    }
}

#Preview {
    NavigationView {
        GuidesListView()
    }
}
