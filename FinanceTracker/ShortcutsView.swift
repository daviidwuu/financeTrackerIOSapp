import SwiftUI

struct ShortcutsView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme
    @State private var showCopiedAlert = false
    @State private var showShareSheet = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.white)
                    Text("Apple Shortcuts")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Add transactions using Siri or Shortcuts")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)
                
                // User ID Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Your User ID")
                        .font(.headline)
                    
                    HStack {
                        Text(appState.currentUserId)
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        
                        Spacer()
                        
                        Button(action: {
                            UIPasteboard.general.string = appState.currentUserId
                            showCopiedAlert = true
                            HapticManager.shared.success()
                        }) {
                            Label("Copy", systemImage: "doc.on.doc")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                
                // Create Shortcut Button
                VStack(spacing: 12) {
                    Button(action: {
                        shareShortcutURL()
                    }) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                                .font(.title3)
                            Text("Share Shortcut Template")
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(colorScheme == .dark ? .black : .white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(colorScheme == .dark ? Color.white : Color.black)
                        .cornerRadius(16)
                    }
                    
                    Text("Save the shortcut template with your UID pre-configured")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal)
                
                Spacer()
            }
        }
        .navigationTitle("Shortcuts")
        .background(colorScheme == .dark ? Color.black : Color(UIColor.systemGroupedBackground))
        .alert("Copied!", isPresented: $showCopiedAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("User ID copied to clipboard")
        }
        .sheet(isPresented: $showShareSheet) {
            ShareShortcutView(userId: appState.currentUserId)
        }
    }
    
    private func shareShortcutURL() {
        // Create iCloud link or share sheet
        showShareSheet = true
        HapticManager.shared.success()
    }
}

struct ShareShortcutView: View {
    let userId: String
    @Environment(\.dismiss) var dismiss
    
    var shortcutText: String {
        """
        📱 Shortcut Setup Steps:

        1. Open Shortcuts app
        2. Tap + to create new shortcut
        3. Add "Dictionary" action
        4. Configure dictionary with these keys:
           • UserID: Text → "\(userId)"
           • Data: Dictionary with:
             - Category: Ask Each Time
             - Type: Text → "expense" or "income"
             - Amount: Ask Each Time (Number)
             - Notes: Ask Each Time
        
        5. Add "Get Contents of URL"
           • URL: [See below - get from Firebase Console]
           • Method: POST
           • Request Body: JSON
           • Body: [Dictionary from step 4]
        
        6. Add "Show Notification"
           • Title: "Transaction Added"
           • Body: "✅ Saved [Category] - $[Amount]"
        
        7. Name it "Add Expense"
        
        🔔 IMPORTANT: The notification in step 6 happens on YOUR device.
        The app won't receive a notification from shortcuts - only when you
        add transactions directly in the app.
        
        🔗 Getting Your URL:
        1. Go to Firebase Console
        2. Navigate to Functions
        3. Deploy the function (see setup guide)
        4. Copy the URL that looks like:
           https://us-central1-YOUR-PROJECT.cloudfunctions.net/addTransaction
        
        💡 Your UserID is already here: \(userId)
        """
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(shortcutText)
                        .font(.system(.body, design: .monospaced))
                        .padding()
                    
                    Button(action: {
                        UIPasteboard.general.string = userId
                        HapticManager.shared.success()
                    }) {
                        HStack {
                            Image(systemName: "doc.on.doc")
                            Text("Copy User ID")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                }
            }
            .navigationTitle("Setup Instructions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationView {
        ShortcutsView()
            .environmentObject(AppState.shared)
    }
}
