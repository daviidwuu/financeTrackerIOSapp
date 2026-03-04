import SwiftUI

struct GuestCardView: View {
    let guest: FirestoreModels.Guest

    var body: some View {
        let avatarColor: Color = {
            let hex = guest.avatarColor.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !hex.isEmpty else { return Color.random(seed: guest.name) }
            return Color(hex: hex)
        }()

        HStack(spacing: AppSpacing.element) {
            ProfileAvatar(
                text: String(guest.name.prefix(1)),
                color: avatarColor,
                size: AppSize.avatarList
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(guest.name)
                    .font(.headline)
                    .foregroundColor(.primary)

                Text("@" + String(guest.name.split(separator: " ").first ?? "").lowercased() + "_guest")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text("Guest")
                .font(.caption2)
                .fontWeight(.bold)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.orange.opacity(0.15))
                .foregroundColor(.orange)
                .clipShape(Capsule())

            CardChevron()
        }
        .appCardStyle()
    }
}
