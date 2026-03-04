import SwiftUI

struct WhatsNewView: View {
    @Environment(\.dismiss) private var dismiss
    
    let version: String
    let items: [String]
    let onDismiss: (() -> Void)?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: AppSpacing.section) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("What’s New")
                                .font(.title2)
                                .fontWeight(.semibold)
                            
                            Text(version)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(items, id: \.self) { item in
                                HStack(alignment: .top, spacing: 12) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.primary)
                                    
                                    Text(item)
                                        .font(.body)
                                        .foregroundColor(.primary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }
                    }
                    .padding(AppSpacing.margin)
                }
                
                Button { HapticManager.shared.light(); 
                    onDismiss?()
                    dismiss()
                } label: {
                    Text("Continue")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.primary)
                        .foregroundColor(Color.backgroundPrimary)
                        .clipShape(Capsule())
                }
                .padding(.horizontal, AppSpacing.margin)
                .padding(.bottom, AppSpacing.margin)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { HapticManager.shared.light(); 
                        onDismiss?()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
}
