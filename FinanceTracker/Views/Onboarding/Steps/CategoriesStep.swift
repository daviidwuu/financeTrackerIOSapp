import SwiftUI

struct CategoriesStep: View {
    @Binding var categories: [OnboardingCategory]
    @State private var showAddCategory = false
    @State private var newCategoryName = ""
    @State private var categoryToEdit: OnboardingCategory?
    @State private var editSheetInitialStep = 1
    @State private var showSwipeGuide = false
    @State private var hasShownGuide = false
    
    var body: some View {
        VStack(spacing: 24) {
            Text("Customize Categories")
                .font(AppTypography.heroRounded(size: 28))
                .multilineTextAlignment(.center)
                .padding(.top, 40)
            
            if categories.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "tray.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.gray.opacity(0.3))
                    Text("No categories yet")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal)
            } else {
                List {
                    ForEach(categories) { category in
                        HStack {
                            Image(systemName: category.icon)
                                .frame(width: 40, height: 40)
                                .background(Color(hex: category.colorHex).opacity(0.2))
                                .foregroundColor(Color(hex: category.colorHex))
                                .clipShape(Circle())
                            
                            Text(category.name)
                                .font(.headline)
                            
                            Spacer()
                            
                            if let amount = category.budgetAmount {
                                Text("$\(Int(amount)) Limit")
                                    .font(.system(.subheadline, design: .rounded))
                                    .foregroundColor(.secondary)
                                    .contentShape(Rectangle())
                                    .highPriorityGesture(TapGesture().onEnded {
                                        editSheetInitialStep = 2
                                        categoryToEdit = category
                                    })
                            } else {
                                Text("Set Budget")
                                    .font(.system(.subheadline, design: .rounded))
                                    .foregroundColor(.secondary)
                                    .contentShape(Rectangle())
                                    .highPriorityGesture(TapGesture().onEnded {
                                        editSheetInitialStep = 2
                                        categoryToEdit = category
                                    })
                            }
                        }
                        .padding()
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(AppRadius.medium)
                        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .padding(.bottom, 8)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            editSheetInitialStep = 1
                            categoryToEdit = category
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            Button {
                                HapticManager.shared.medium()
                                categoryToEdit = category
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button {
                                HapticManager.shared.heavy()
                                if let index = categories.firstIndex(where: { $0.id == category.id }) {
                                    categories.remove(at: index)
                                }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            .tint(.red)
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .scrollIndicators(.hidden)
            }
            
            Button(action: {
                // Create a new empty category and open the sheet
                let newCat = OnboardingCategory(name: "", icon: "tag.fill", colorHex: "#808080")
                categoryToEdit = newCat
            }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Category")
                }
                .font(.headline)
                .foregroundColor(.primary)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.clear)
                .cornerRadius(AppRadius.small)
                .padding(.horizontal)
            }

        }
            .overlay {
                if showSwipeGuide {
                    SwipeGuideView(onDismiss: {
                        showSwipeGuide = false
                        hasShownGuide = true
                    })
                }
            }
            .onAppear {
                if !hasShownGuide {
                    // Slight delay to allow view to appear fully
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        showSwipeGuide = true
                    }
                }
            }
            .sheet(item: $categoryToEdit) { category in
                EditCategorySheet(
                    category: category,
                    initialStep: editSheetInitialStep,
                    onSave: { updatedCategory in
                        if let index = categories.firstIndex(where: { $0.id == updatedCategory.id }) {
                            categories[index] = updatedCategory
                        } else {
                            // Append new category if ID not found (newly created)
                            // Note: ID for newCat is created on init, so it won't match any existing category unless we strictly check against the list content which holds value types.
                            // Actually, OnboardingCategory is a struct and id is let UUID().
                            // 'categoryToEdit' has a UUID. If that UUID is in 'categories', update. Else, append.
                            // However, since 'categories' is [OnboardingCategory], we need to check if an item with that ID exists.
                            // When we created 'newCat', it has a unique ID. It is NOT in 'categories' yet.
                            // So 'firstIndex' returns nil. We append. Correct.
                            categories.append(updatedCategory)
                        }
                        categoryToEdit = nil
                    },
                    onDelete: {
                        if let index = categories.firstIndex(where: { $0.id == category.id }) {
                            categories.remove(at: index)
                        }
                        categoryToEdit = nil
                    }
                )
            }
    }
}
