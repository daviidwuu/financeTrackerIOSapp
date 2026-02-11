import SwiftUI

extension FriendsListView {
    var mainContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Segmented Control
                Picker("View", selection: $selectedTab) {
                    Text("Friends").tag(0)
                    Text("Groups").tag(1)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal, 16)
                .padding(.top, 16)
                
                if selectedTab == 0 {
                    friendsTab
                } else {
                    groupsTab
                }
                
                Spacer()
            }
            .padding(.bottom, 20)
        }
    }
}
