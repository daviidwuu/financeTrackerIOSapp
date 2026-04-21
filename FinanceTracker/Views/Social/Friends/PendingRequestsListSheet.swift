import SwiftUI

struct PendingRequestsListSheet: View {
    let incomingRequests: [FirestoreModels.SplitRequest]
    let outgoingRequests: [FirestoreModels.SplitRequest]
    let counterpartyName: String
    
    let onAction: (RequestAction, FirestoreModels.SplitRequest) -> Void
    let onCardTap: (FirestoreModels.SplitRequest) -> Void
    
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        ZStack(alignment: .top) {
            Color.backgroundPrimary.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Image(systemName: "list.clipboard.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(Color.orange)
                        .clipShape(Circle())
                    
                    Text("Pending Requests")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(Color(UIColor.tertiaryLabel))
                    }
                }
                .padding(.horizontal, AppSpacing.margin)
                .padding(.vertical, 16)
                .background(Color.backgroundPrimary)
                
                ScrollView {
                    VStack(spacing: 24) {
                        if !incomingRequests.isEmpty {
                            actionRequiredSection
                        }
                        
                        if !outgoingRequests.isEmpty {
                            yourRequestsSection
                        }
                    }
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
            }
        }
    }
    
    @ViewBuilder
    private var actionRequiredSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.circle.fill").foregroundColor(.orange)
                Text("Action Required").font(.headline)
                Spacer()
                Text("\(incomingRequests.count)")
                    .font(.caption).fontWeight(.bold).foregroundColor(.white)
                    .padding(6).background(AppColors.functionalExpense).clipShape(Circle())
            }
            .padding(.horizontal, AppSpacing.margin)
            
            VStack(spacing: 12) {
                ForEach(incomingRequests) { split in
                    let presentation = split.presentation(for: appState.currentUserId, counterpartyName: counterpartyName)
                    PendingSplitCard(
                        split: split,
                        userId: appState.currentUserId,
                        presentation: presentation,
                        onAction: { action in
                            onAction(action, split)
                        }
                    )
                    .onTapGesture {
                        HapticManager.shared.light()
                        onCardTap(split)
                    }
                }
            }
            .padding(.horizontal, AppSpacing.margin)
        }
    }
    
    @ViewBuilder
    private var yourRequestsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "paperplane.fill").foregroundColor(.blue)
                Text("Your Requests").font(.headline)
                Spacer()
                Text("\(outgoingRequests.count)")
                    .font(.caption).fontWeight(.bold).foregroundColor(.white)
                    .padding(6).background(Color.blue).clipShape(Circle())
            }
            .padding(.horizontal, AppSpacing.margin)
            
            VStack(spacing: 12) {
                ForEach(outgoingRequests) { split in
                    let presentation = split.presentation(for: appState.currentUserId, counterpartyName: counterpartyName)
                    PendingSplitCard(
                        split: split,
                        userId: appState.currentUserId,
                        presentation: presentation,
                        onAction: { action in
                            onAction(action, split)
                        }
                    )
                    .onTapGesture {
                        HapticManager.shared.light()
                        onCardTap(split)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        if presentation.secondaryAction == .cancelRequest {
                            Button(role: .destructive) {
                                HapticManager.shared.light()
                                onAction(.cancelRequest, split)
                            } label: {
                                Label("Cancel", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, AppSpacing.margin)
        }
    }
}
