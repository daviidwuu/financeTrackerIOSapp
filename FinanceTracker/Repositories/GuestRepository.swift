import Foundation
import FirebaseFirestore
import Combine

class GuestRepository: ObservableObject {
    @Published var guests: [FirestoreModels.Guest] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    
    private let db = Firestore.firestore()
    private var userId: String?
    private var listener: ListenerRegistration?
    
    func startListening(userId: String) {
        self.userId = userId
        // Only show loading if we don't have any data yet (Stale-While-Revalidate)
        if guests.isEmpty {
            self.isLoading = true
        }
        self.errorMessage = nil
        
        listener = db.collection("users").document(userId).collection("guests")
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                self.isLoading = false
                
                if let error = error {
                    self.errorMessage = "Error fetching guests: \(error.localizedDescription)"
                    DebugLogger.log("Error fetching guests: \(error.localizedDescription)")
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    self.errorMessage = "No guests found."
                    return
                }
                
                self.errorMessage = nil
                self.guests = documents.compactMap { document in
                    try? document.data(as: FirestoreModels.Guest.self)
                }
            }
    }
    
    func stopListening() {
        listener?.remove()
        userId = nil
        guests = []
    }
    
    func createGuest(name: String) async throws -> FirestoreModels.Guest {
        guard let userId = userId else { throw NSError(domain: "GuestRepository", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not logged in"]) }
        
        let ref = db.collection("users").document(userId).collection("guests").document()
        
        let newGuest = FirestoreModels.Guest(
            id: ref.documentID,
            name: name,
            avatarColor: randomHexColor(),
            totalOwed: 0.0,
            createdAt: Date(),
            userId: userId
        )
        
        try ref.setData(from: newGuest)
        return newGuest
    }
    
    // Smart Intercept: Substring Matching (Decision #3)
    func findMatchingGuests(friendName: String) -> [FirestoreModels.Guest] {
        guard !friendName.isEmpty else { return [] }
        return guests.filter { guest in
            guest.name.localizedCaseInsensitiveContains(friendName)
        }
    }
    
    private func randomHexColor() -> String {
        let colors = ["#FF5733", "#33FF57", "#3357FF", "#F333FF", "#33FFF3", "#F3FF33"]
        return colors.randomElement() ?? "#CCCCCC"
    }
}
