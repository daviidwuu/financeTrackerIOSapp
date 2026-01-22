import SwiftUI

struct SwipeGuideView: View {
    var onDismiss: () -> Void
    @State private var offset: CGFloat = 0
    @State private var showEdit = false
    @State private var showDelete = false
    @State private var guideText = "Swipe Right to Edit"
    
    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture {
                    onDismiss()
                }
            
            VStack(spacing: 40) {
                Spacer()
                
                // Mock Row
                ZStack {
                    // Background Actions
                    HStack {
                        if showEdit {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.blue)
                                .overlay(
                                    Image(systemName: "pencil")
                                        .foregroundColor(.white)
                                        .padding(.leading, 20),
                                    alignment: .leading
                                )
                        } else if showDelete {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.red)
                                .overlay(
                                    Image(systemName: "trash")
                                        .foregroundColor(.white)
                                        .padding(.trailing, 20),
                                    alignment: .trailing
                                )
                        } else {
                            Color.clear
                        }
                    }
                    .cornerRadius(16)
                    
                    // Row Content
                    HStack {
                        Image(systemName: "fork.knife")
                            .frame(width: 40, height: 40)
                            .background(Color.orange.opacity(0.2))
                            .foregroundColor(.orange)
                            .clipShape(Circle())
                        
                        Text("Food & Drink")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Text("Set Budget")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(16)
                    .offset(x: offset)
                }
                .frame(height: 70)
                .padding(.horizontal, 20)
                
                // Instructions
                Text(guideText)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .transition(.opacity)
                    .id(guideText) // Force redraw for transition
                
                Spacer()
                
                Text("Tap anywhere to continue")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.bottom, 50)
            }
        }
        .task {
            await startAnimationLoop()
        }
    }
    
    private func startAnimationLoop() async {
        // Use a loop to keep animating
        while !Task.isCancelled {
            // Step 1: Swipe Right (Edit)
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                showEdit = true
                showDelete = false
                offset = 100
                guideText = "Swipe Right to Edit"
            }
            
            try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5s hold
            
            // Step 2: Reset
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                offset = 0
                showEdit = false
            }
            
            try? await Task.sleep(nanoseconds: 800_000_000) // 0.8s pause
            
            // Step 3: Swipe Left (Delete)
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                showEdit = false
                showDelete = true
                offset = -100
                guideText = "Swipe Left to Delete"
            }
            
            try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5s hold
            
            // Step 4: Reset
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                offset = 0
                showDelete = false
            }
            
            try? await Task.sleep(nanoseconds: 800_000_000) // 0.8s pause
        }
    }
}
