import SwiftUI
import MapKit

struct FullScreenMapView: View {
    let coordinate: CLLocationCoordinate2D
    let title: String
    
    @Environment(\.dismiss) var dismiss
    
    // Simplified init
    init(coordinate: CLLocationCoordinate2D, title: String) {
        self.coordinate = coordinate
        self.title = title
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            // Map Layer
            Map(initialPosition: .camera(MapCamera(centerCoordinate: coordinate, distance: 1000))) {
                Marker(title, coordinate: coordinate)
            }
            .ignoresSafeArea()
            
            // Clean Floating Header - Only Back Button
            DetailHeaderView(
                title: "",
                subtitle: "",
                onBack: { dismiss() },
                backIcon: "xmark",
                onMenu: nil,
                backgroundColor: Color.clear,
                textColor: .black,
                avatar: { EmptyView() },
                actions: { EmptyView() }
            )
        }
    }
}
