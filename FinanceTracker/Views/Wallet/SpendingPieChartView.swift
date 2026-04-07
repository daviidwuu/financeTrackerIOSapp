import SwiftUI
import Charts

// MARK: - Data Model

private struct CategorySpend: Identifiable {
    let id: String
    let name: String
    let icon: String
    let colorHex: String
    let amount: Double
    let percentage: Double
}

// MARK: - Main View

struct SpendingPieChartView: View {
    let transactions: [FirestoreModels.TransactionModel]
    let categories: [FirestoreModels.CategoryBudget]
    var onCategoryTapped: ((String) -> Void)? = nil

    @State private var selectedName: String? = nil

    // MARK: - Computed Data

    private var spendingData: [CategorySpend] {
        let expenses = transactions.filter { $0.type == "expense" }
        guard !expenses.isEmpty else { return [] }

        var grouped: [String: Double] = [:]
        for tx in expenses {
            let key = tx.categoryId ?? "__uncategorized__"
            grouped[key, default: 0] += abs(tx.amount)
        }

        let total = grouped.values.reduce(0, +)
        guard total > 0 else { return [] }

        let sorted = grouped.sorted { $0.value > $1.value }
        let topEntries = sorted.prefix(5)
        let otherAmount = sorted.dropFirst(5).reduce(0) { $0 + $1.value }

        var result: [CategorySpend] = []
        var unresolvableAmount: Double = 0

        for (catId, amount) in topEntries {
            if let budget = categories.first(where: { $0.id == catId }) {
                result.append(CategorySpend(
                    id: catId,
                    name: budget.category,
                    icon: budget.icon,
                    colorHex: budget.colorHex,
                    amount: amount,
                    percentage: amount / total * 100
                ))
            } else {
                unresolvableAmount += amount
            }
        }

        let combinedOther = otherAmount + unresolvableAmount
        if combinedOther > 0.01 {
            result.append(CategorySpend(
                id: "__other__",
                name: "Other",
                icon: "ellipsis.circle.fill",
                colorHex: "#8E8E93",
                amount: combinedOther,
                percentage: combinedOther / total * 100
            ))
        }

        return result.sorted { $0.amount > $1.amount }
    }

    private var totalSpend: Double {
        spendingData.reduce(0) { $0 + $1.amount }
    }

    private var selectedItem: CategorySpend? {
        guard let name = selectedName else { return nil }
        return spendingData.first { $0.name == name }
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.element) {
            if spendingData.isEmpty {
                emptyState
            } else {
                donutChart
                Divider().padding(.vertical, AppSpacing.micro)
                legendGrid
            }
        }
        .padding(AppSpacing.margin)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.large))
    }

    // Tap handler shared by both chart and legend
    private func handleSelection(of item: CategorySpend) {
        if selectedName == item.name {
            // Second tap → drill down (skip "Other" which has no single category)
            if item.id != "__other__" {
                HapticManager.shared.medium()
                onCategoryTapped?(item.name)
            }
        } else {
            // First tap → select
            HapticManager.shared.light()
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedName = item.name
            }
        }
    }

    // MARK: - Sub-views

    private var emptyState: some View {
        VStack(spacing: AppSpacing.compact) {
            Image(systemName: "chart.pie")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("No spending this month")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.section)
    }

    private var donutChart: some View {
        ZStack {
            Chart(spendingData) { item in
                SectorMark(
                    angle: .value("Amount", item.amount),
                    innerRadius: .ratio(0.58),
                    angularInset: 2.5
                )
                .foregroundStyle(Color(hex: item.colorHex))
                .opacity(selectedName == nil || selectedName == item.name ? 1.0 : 0.3)
                .cornerRadius(5)
            }
            .frame(height: 220)
            .allowsHitTesting(false) // custom overlay handles taps

            centerLabel

            // Tap overlay: maps touch angle to the correct sector.
            // Uses simultaneousGesture so vertical drags are still passed
            // through to the parent List's scroll recogniser.
            GeometryReader { geo in
                Color.clear
                    .contentShape(Rectangle())
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 0)
                            .onEnded { handleChartTap(at: $0.location, in: geo) }
                    )
            }
            .frame(height: 220)
        }
    }

    private var centerLabel: some View {
        VStack(spacing: 2) {
            if let selected = selectedItem {
                Image(systemName: selected.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color(hex: selected.colorHex))
                Text("$\(Int(selected.amount))")
                    .font(.system(.headline, design: .rounded).weight(.bold))
                Text(String(format: "%.0f%%", selected.percentage))
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Text("Spent")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("$\(Int(totalSpend))")
                    .font(.system(.title3, design: .rounded).weight(.bold))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: selectedName)
        .frame(width: 90)
        .multilineTextAlignment(.center)
    }

    private var legendGrid: some View {
        let columns = [GridItem(.flexible()), GridItem(.flexible())]
        return LazyVGrid(columns: columns, alignment: .leading, spacing: AppSpacing.compact) {
            ForEach(spendingData) { item in
                legendRow(item)
            }
        }
    }

    private func legendRow(_ item: CategorySpend) -> some View {
        let isSelected = selectedName == item.name
        return HStack(spacing: AppSpacing.compact) {
            Circle()
                .fill(Color(hex: item.colorHex))
                .frame(width: 10, height: 10)
                .scaleEffect(isSelected ? 1.4 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.name)
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundColor(isSelected ? .primary : .secondary)
                    .lineLimit(1)
                Text("$\(Int(item.amount))")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundColor(isSelected ? Color(hex: item.colorHex) : .secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, AppSpacing.micro)
        .contentShape(Rectangle())
        .onTapGesture {
            handleSelection(of: item)
        }
    }

    // MARK: - Chart Tap Logic

    private func handleChartTap(at point: CGPoint, in geo: GeometryProxy) {
        let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
        let dx = point.x - center.x
        let dy = point.y - center.y
        let radius = sqrt(dx * dx + dy * dy)

        let maxRadius = min(geo.size.width, geo.size.height) / 2
        let innerRadius = maxRadius * 0.58

        // Tapped the hole or outside the ring → deselect
        guard radius >= innerRadius && radius <= maxRadius else {
            withAnimation(.easeInOut(duration: 0.2)) { selectedName = nil }
            return
        }

        // Angle from top (12 o'clock), clockwise, in [0, 2π]
        var angle = atan2(dy, dx) + .pi / 2
        if angle < 0 { angle += 2 * .pi }

        let fraction = angle / (2 * .pi)
        let targetAmount = fraction * totalSpend

        var cumulative = 0.0
        for item in spendingData {
            cumulative += item.amount
            if targetAmount <= cumulative {
                handleSelection(of: item)
                return
            }
        }
    }
}
