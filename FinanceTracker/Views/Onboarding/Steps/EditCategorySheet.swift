import SwiftUI

struct EditCategorySheet: View {
    @State var category: OnboardingCategory
    var initialStep: Int = 1
    var onSave: (OnboardingCategory) -> Void
    var onDelete: () -> Void
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    // Wizard State
    @State private var currentStep = 1
    @State private var direction: Edge = .trailing
    @State private var presentationDetent: PresentationDetent = .medium
    
    // Form Data
    @State private var name: String = ""
    @State private var amountString: String = ""
    @State private var selectedIcon: String = ""
    @State private var selectedColorHex: String = ""
    
    // Constants
    // Constants
    let icons = AppConstants.allIcons
    let colors = AppConstants.allColors
    
    var body: some View {
        ZStack {
            Color.backgroundPrimary
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Spacer().frame(height: 56)

                Spacer()
                
                // Content
                ZStack(alignment: .top) {
                    currentStepView
                }
                .id(currentStep)
                .transition(.asymmetric(
                    insertion: .move(edge: direction),
                    removal: .move(edge: direction == .leading ? .trailing : .leading)
                ))
                .padding(.horizontal)
                
                Spacer()
                
                // Action Button
                Button(action: { HapticManager.shared.light(); 
                    // Sticky Logic: Enforce Large Detent
                    presentationDetent = .large
                    
                    if currentStep < 4 {
                        HapticManager.shared.light()
                        direction = .trailing
                        currentStep += 1
                    } else {
                        HapticManager.shared.success()
                        saveChanges()
                    }
                }) {
                    Text(currentStep < 4 ? "Next" : "Save Changes")
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!isStepValid)
                .padding(.horizontal, 24)
                .padding(.bottom, 8)
            }
        }
        .overlayHeader(.navigation(
            title: "Step \(currentStep) of 4",
            onBack: {
                if currentStep > 1 {
                    direction = .leading
                    currentStep -= 1
                } else {
                    dismiss()
                }
            },
            backIcon: currentStep > 1 ? "chevron.left" : "xmark",
            trailing: currentStep == 1 ? AnyView(
                Button(action: {
                    HapticManager.shared.heavy()
                    onDelete()
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(AppColors.functionalExpense)
                        .frame(width: AppSize.iconButton, height: AppSize.iconButton)
                }
            ) : nil
        ))
        .presentationDetents([.medium, .large], selection: $presentationDetent)
        .presentationDragIndicator(.visible)
        .onAppear {
            // Initialize state
            currentStep = initialStep
            name = category.name
            selectedIcon = category.icon
            selectedColorHex = category.colorHex
            if let amount = category.budgetAmount, amount != 0 {
                amountString = String(format: "%.0f", amount)
            }
        }
    }
    
    private func saveChanges() {
        var updatedCategory = category
        updatedCategory.name = name
        updatedCategory.icon = selectedIcon
        updatedCategory.colorHex = selectedColorHex
        
        if let amount = Double(amountString), amount > 0 {
            updatedCategory.budgetAmount = amount
        } else {
            updatedCategory.budgetAmount = nil
        }
        
        onSave(updatedCategory)
        dismiss()
    }
    
    private var isStepValid: Bool {
        switch currentStep {
        case 1: return !name.isEmpty
        case 2: return true // Budget is optional
        case 3: return !selectedIcon.isEmpty
        case 4: return !selectedColorHex.isEmpty
        default: return false
        }
    }
    
    @ViewBuilder
    private var currentStepView: some View {
        switch currentStep {
        case 1: nameStep
        case 2: limitStep
        case 3: iconStep
        case 4: colorStep
        default: EmptyView()
        }
    }
    
    // MARK: - Steps
    
    private var nameStep: some View {
        VStack(spacing: 16) {
            Text("Category Name")
                .font(AppTypography.sectionHeader)
                .foregroundColor(.secondary)
            
            TextField("e.g. Rent", text: $name)
                .font(AppTypography.heroInput) // Use standardized Hero font
                .multilineTextAlignment(.center)
                .foregroundColor(.primary)
                .padding()
                .background(Color.clear)
        }
    }
    
    private var limitStep: some View {
        VStack(spacing: 16) {
            Text("Budget Limit")
                .font(AppTypography.sectionHeader)
                .foregroundColor(.secondary)
            
            TextField("Optional", text: $amountString)
                .font(AppTypography.heroRounded(size: 64))
                .multilineTextAlignment(.center)
                .keyboardType(.decimalPad)
                .foregroundColor(.primary)
            
            Text("Leave empty for no limit")
                .font(AppTypography.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var iconStep: some View {
        VStack(spacing: 24) {
            Text("Select Icon")
                .font(AppTypography.sectionHeader)
                .foregroundColor(.secondary)
            
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 60))], spacing: 20) {
                    ForEach(icons, id: \.self) { icon in
                        Button(action: { HapticManager.shared.light();  
                            selectedIcon = icon 
                            HapticManager.shared.selection()
                        }) {
                            Circle()
                                .fill(selectedIcon == icon ? Color.primary : Color.secondary.opacity(0.1))
                                .frame(width: 60, height: 60)
                                .overlay(
                                    Image(systemName: icon)
                                        .font(.title2)
                                        .foregroundColor(selectedIcon == icon ? (colorScheme == .dark ? .black : .white) : .primary)
                                )
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 20) // Add padding for bottom spacing
            }
        }
    }
    
    private var colorStep: some View {
        VStack(spacing: 24) {
            Text("Select Color")
                .font(AppTypography.sectionHeader)
                .foregroundColor(.secondary)
            
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 60))], spacing: 20) {
                    ForEach(colors, id: \.self) { color in
                        let hex = color.toHex() ?? "#000000"
                        Button(action: { HapticManager.shared.light();  
                            selectedColorHex = hex
                            HapticManager.shared.selection()
                        }) {
                            Circle()
                                .fill(color)
                                .frame(width: 60, height: 60)
                                .overlay(
                                    Circle()
                                        .stroke(Color.primary, lineWidth: selectedColorHex == hex ? 3 : 0)
                                )
                                .overlay(
                                    Image(systemName: "checkmark")
                                        .font(.title3)
                                        .foregroundColor(.white)
                                        .opacity(selectedColorHex == hex ? 1 : 0)
                                )
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 20)
            }
        }
    }
}
