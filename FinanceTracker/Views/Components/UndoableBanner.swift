import SwiftUI

// MARK: - UndoState

/// Manages a soft-delete with a timed undo window.
/// The item is hidden from the UI immediately, but the actual delete
/// is deferred until the undo timer expires.
@Observable
class UndoState {
    var label: String?
    var isVisible: Bool { label != nil }
    
    private var confirmAction: (() -> Void)?
    private var undoAction: (() -> Void)?
    private var timerTask: Task<Void, Never>?
    
    /// Schedule a soft-delete with undo.
    /// - Parameters:
    ///   - label: Display text (e.g., "Transaction deleted")
    ///   - duration: Seconds before permanent delete (default 3s)
    ///   - onUndo: Called if user taps Undo — restore the item
    ///   - onConfirm: Called when timer expires — execute permanent delete
    func schedule(
        label: String,
        duration: TimeInterval = 3.0,
        onUndo: @escaping () -> Void,
        onConfirm: @escaping () -> Void
    ) {
        // Cancel any previous pending delete
        timerTask?.cancel()
        
        self.label = label
        self.undoAction = onUndo
        self.confirmAction = onConfirm
        
        timerTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            if !Task.isCancelled {
                self.confirmAction?()
                withAnimation(.easeOut(duration: 0.3)) {
                    self.label = nil
                }
                self.cleanup()
            }
        }
    }
    
    func undo() {
        timerTask?.cancel()
        undoAction?()
        HapticManager.shared.light()
        withAnimation(.easeOut(duration: 0.3)) {
            label = nil
        }
        cleanup()
    }
    
    func dismiss() {
        timerTask?.cancel()
        confirmAction?()
        withAnimation(.easeOut(duration: 0.3)) {
            label = nil
        }
        cleanup()
    }
    
    private func cleanup() {
        confirmAction = nil
        undoAction = nil
        timerTask = nil
    }
}

// MARK: - UndoableBanner View

struct UndoableBanner: View {
    let label: String
    let onUndo: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "trash.fill")
                .font(.body)
                .foregroundColor(.red)
            
            Text(label)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            Spacer()

            Button(action: {
                HapticManager.shared.light()
                onUndo()
            }) {
                Text("Undo")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
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

struct UndoableBannerModifier: ViewModifier {
    @Bindable var undoState: UndoState
    
    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if let label = undoState.label {
                    UndoableBanner(label: label, onUndo: { undoState.undo() })
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.bottom, 16)
                        .zIndex(999)
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: undoState.label)
    }
}

extension View {
    func undoableBanner(_ undoState: UndoState) -> some View {
        modifier(UndoableBannerModifier(undoState: undoState))
    }
}
