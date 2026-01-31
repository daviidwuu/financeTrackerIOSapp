import SwiftUI
import AppIntents

struct ShortcutsView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        List {
            Section {
                VStack(spacing: 16) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.white)
                        .padding(.vertical, 10)
                    
                    Text("spendie Shortcuts")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Log transactions instantly with Siri or the Shortcuts app.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    if #available(iOS 16.0, *) {
                        ShortcutsLink()
                            .shortcutsLinkStyle(.darkOutline)
                            .padding(.top, 10)
                    } else {
                        Text("Please update to iOS 16 to use App Shortcuts.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }
            
            Section(header: Text("Available Voice Commands")) {
                CommandRow(command: "Log Transaction", description: "Logs a new expense with categories from your budget.")
                CommandRow(command: "Log Transaction with Note", description: "Adds a note to your transaction entry.")
            }
            
            Section(footer: Text("You can customize these phrases in the Shortcuts app.")) {
                // Info section
            }
        }
        .navigationTitle("Shortcuts")
        .background(Color.listBackground)
        .scrollContentBackground(.hidden)
    }
}

struct CommandRow: View {
    let command: String
    let description: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Hey Siri, \(command)")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
            }
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationView {
        ShortcutsView()
            .environmentObject(AppState.shared)
    }
}
