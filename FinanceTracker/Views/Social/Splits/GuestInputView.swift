import SwiftUI

struct GuestInputView: View {
    @Environment(\.dismiss) var dismiss

    @State private var guestName: String = ""
    var onSave: (String) -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        ZStack {
            Color.backgroundPrimary
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Header
                ModalHeader(
                    title: "Guest Name",
                    currentStep: 1,
                    totalSteps: 1,
                    onBack: nil,
                    onClose: { dismiss() }
                )
                .padding(.horizontal, AppSpacing.margin)
                .padding(.top, 16)
                
                Spacer()
                
                TextField("Enter Name", text: $guestName)
                    .font(AppTypography.heroInput)
                    .multilineTextAlignment(.center)
                    .submitLabel(.done)
                    .focused($isFocused)
                    .onSubmit {
                        if !guestName.isEmpty {
                            onSave(guestName)
                            dismiss()
                        }
                    }
                
                Spacer()
                
                Button(action: { HapticManager.shared.light(); 
                    if !guestName.isEmpty {
                        onSave(guestName)
                        dismiss()
                    }
                }) {
                    Text("Add Guest")
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(guestName.isEmpty)
                .padding(.horizontal, AppSpacing.margin)
                .padding(.bottom)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isFocused = true
            }
        }
    }
}
