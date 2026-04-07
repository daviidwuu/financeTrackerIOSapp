import SwiftUI

struct SearchBar: View {
    @Binding var text: String
    var placeholder: String = "Search..."
    var onSearch: () -> Void = {}
    
    // Binding to show/hide loading indicator if needed, or just rely on parent
    var isLoading: Bool = false

    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .accessibilityHidden(true)
            
            TextField(placeholder, text: $text)
                .font(.body)
                .submitLabel(.search)
                .onSubmit(onSearch)
            
            if isLoading {
                ProgressView()
                    .scaleEffect(0.8)
                    .padding(.trailing, 4)
            } else if !text.isEmpty {
                Button(action: { HapticManager.shared.light();
                    text = ""
                    // Optional: trigger empty search or just clear
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(Color.secondaryCardBackground)
        .clipShape(Capsule())
        .frame(height: 44) // Consistent height target
    }
}

struct SearchBar_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            SearchBar(text: .constant(""))
            SearchBar(text: .constant("Test"), isLoading: true)
        }
        .padding()
    }
}
