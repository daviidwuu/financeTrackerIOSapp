import SwiftUI

struct WizardLayout<Content: View, ActionBar: View>: View {
    let title: String
    let currentStep: Int
    let totalSteps: Int
    let onBack: (() -> Void)?
    let onClose: () -> Void
    let direction: Edge
    
    @ViewBuilder let content: () -> Content
    @ViewBuilder let actionBar: () -> ActionBar
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ZStack {
            // Background
            (colorScheme == .dark ? Color.black : Color.white)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Header
                ModalHeader(
                    title: title,
                    currentStep: currentStep,
                    totalSteps: totalSteps,
                    onBack: onBack,
                    onClose: onClose
                )
                .padding(.horizontal, AppSpacing.margin)
                .padding(.top, 16)
                
                // Content with Transition
                ZStack(alignment: .top) {
                    content()
                }
                .id(currentStep)
                .transition(.asymmetric(
                    insertion: .move(edge: direction),
                    removal: .move(edge: direction == .leading ? .trailing : .leading)
                ))
                .frame(maxHeight: .infinity, alignment: .top)
                
                Spacer()
            }
            .safeAreaInset(edge: .bottom) {
                actionBar()
                    .padding(.horizontal, AppSpacing.margin)
                    .padding(.top, AppSpacing.compact)
                    .padding(.bottom, 8)
                    .background(Color.backgroundPrimary)
            }
        }
    }
}
