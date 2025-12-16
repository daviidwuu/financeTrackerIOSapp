import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Image(systemName: "square.grid.2x2.fill")
                    Text("Dashboard")
                }
            
            WalletView()
                .tabItem {
                    Image(systemName: "creditcard.fill")
                    Text("Wallet")
                }
        }
        .preferredColorScheme(.none) // Respect system setting
    }
}

#Preview {
    ContentView()
}
