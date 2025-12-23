import SwiftUI

struct ModalHeader: View {
    let title: String
    let currentStep: Int
    let totalSteps: Int
    var onBack: (() -> Void)?
    var onClose: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Button(action: {
                    HapticManager.shared.light()
                    if let onBack = onBack {
                        onBack()
                    } else {
                        onClose()
                    }
                }) {
                    Image(systemName: onBack != nil ? "chevron.left" : "xmark")
                        .font(.system(size: 18, weight: .semibold)) // Slightly smaller, refined index
                        .foregroundColor(.primary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                
                Spacer()
                
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Invisible placeholder to balance the layout centered
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.clear)
                    .frame(width: 44, height: 44)
            }
            .padding(.horizontal, AppSpacing.compact) // Tighter outer padding for header
            
            // Progress Bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.1))
                        .frame(height: 4)
                    
                    Capsule()
                        .fill(Color.primary)
                        .frame(width: (geometry.size.width / CGFloat(totalSteps)) * CGFloat(currentStep), height: 4)
                        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: currentStep)
                }
            }
            .frame(height: 4)
            .padding(.horizontal, AppSpacing.margin)
        }
        .padding(.bottom, AppSpacing.element)
        .background(Color.backgroundPrimary) // Matches the true black background of the view
    }
}

#Preview {
    VStack {
        ModalHeader(
            title: "Add Transaction",
            currentStep: 2,
            totalSteps: 4,
            onBack: {},
            onClose: {}
        )
        Spacer()
    }
}
