import SwiftUI

// MARK: - ErrorState

/// Observable state for managing error banner display.
/// Inject as @State in a parent view and pass to child views via environment or binding.
@Observable
class ErrorState {
    var message: String?
    private var dismissTask: Task<Void, Never>?
    
    func show(_ message: String, duration: TimeInterval = 3.0) {
        dismissTask?.cancel()
        self.message = message
        HapticManager.shared.error()
        dismissTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            if !Task.isCancelled {
                withAnimation(.easeOut(duration: 0.3)) {
                    self.message = nil
                }
            }
        }
    }
    
    func dismiss() {
        dismissTask?.cancel()
        withAnimation(.easeOut(duration: 0.3)) {
            message = nil
        }
    }
}

// MARK: - ErrorBanner View

struct ErrorBanner: View {
    let message: String
    let onDismiss: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.body)
                .foregroundColor(.red)
            
            Text(message)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .lineLimit(2)
            
            Spacer()
            
            Button(action: {
                HapticManager.shared.light()
                onDismiss()
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.regularMaterial)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)
        .padding(.horizontal, AppSpacing.margin)
    }
}

// MARK: - View Modifier

struct ErrorBannerModifier: ViewModifier {
    @Bindable var errorState: ErrorState
    
    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let message = errorState.message {
                    ErrorBanner(message: message, onDismiss: { errorState.dismiss() })
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .padding(.top, 8)
                        .zIndex(999)
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: errorState.message)
    }
}

extension View {
    func errorBanner(_ errorState: ErrorState) -> some View {
        modifier(ErrorBannerModifier(errorState: errorState))
    }
}
