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
        VStack(spacing: AppSpacing.large) {
            Text("Customize Categories")
                .font(AppTypography.heroRounded(size: 28))
                .multilineTextAlignment(.center)
                .padding(.top, AppSpacing.margin)
            
            Text("Swipe to edit or delete. Tap to customize.")
                .font(AppTypography.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.section)
            
            if categories.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "tray.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary.opacity(0.3))
                    Text("No categories yet")
                        .font(AppTypography.subheadline)
                        .foregroundColor(.secondary)
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
                                .font(AppTypography.headline)
                            
                            Spacer()
                            
                            if let amount = category.budgetAmount {
                                Text("$\(Int(amount)) Limit")
                                    .font(AppTypography.subheadline)
                                    .foregroundColor(.secondary)
                                    .contentShape(Rectangle())
                                    .highPriorityGesture(TapGesture().onEnded {
                                        editSheetInitialStep = 2
                                        categoryToEdit = category
                                    })
                            } else {
                                Text("Set Budget")
                                    .font(AppTypography.subheadline)
                                    .foregroundColor(.secondary)
                                    .contentShape(Rectangle())
                                    .highPriorityGesture(TapGesture().onEnded {
                                        editSheetInitialStep = 2
                                        categoryToEdit = category
                                    })
                            }
                        }
                        .padding()
                        .background(Color.cardBackground)
                        .cornerRadius(AppRadius.medium)
                        .listRowInsets(EdgeInsets(top: 0, leading: AppSpacing.element, bottom: 0, trailing: AppSpacing.element))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .padding(.bottom, AppSpacing.compact)
                        .contentShape(Rectangle())
                        .onTapGesture { HapticManager.shared.light(); 
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
            
            Button(action: { HapticManager.shared.light(); 
                let newCat = OnboardingCategory(name: "", icon: "tag.fill", colorHex: "#808080")
                categoryToEdit = newCat
            }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Category")
                }
                .font(AppTypography.headline)
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
