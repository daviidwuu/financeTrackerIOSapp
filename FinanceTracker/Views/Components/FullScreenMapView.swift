import SwiftUI
import MapKit

struct FullScreenMapView: View {
    let coordinate: CLLocationCoordinate2D
    let title: String
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            Map(initialPosition: .camera(MapCamera(centerCoordinate: coordinate, distance: 1000))) {
                Marker(title, coordinate: coordinate)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
}
