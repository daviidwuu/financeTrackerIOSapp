// MARK: - FC_WizardLayout.swift
// Frontend layer — WizardLayout component catalog for Figma.
// Source: Views/Components/WizardLayout.swift
//
// WizardLayout wraps multi-step sheets:
//   - ModalHeader (title + step progress bar + close/back)
//   - Animated content area (slides in/out per step)
//   - Bottom action bar (primary + secondary buttons)
//
// Used in: AddTransactionView, GroupCreationWizardView,
//          EditGroupTransactionWizardView, SplitConfigurationView

import SwiftUI

// MARK: - Preview Catalog

#Preview("WizardLayout — Step 1 (Amount Entry)") {
    // Replicates the first step of AddTransactionView:
    // Large numeric input in the center, Continue button below.
    WizardLayout(
        title: "Add Transaction",
        currentStep: 1,
        totalSteps: 3,
        onBack: nil,
        onClose: {},
        direction: .trailing
    ) {
        // Step content
        VStack(spacing: AppSpacing.section) {
            Spacer().frame(height: AppSpacing.section)

            // Amount display
            VStack(spacing: AppSpacing.compact) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("$")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)
                    Text("24.50")
                        .font(AppTypography.heroInput)
                        .foregroundColor(.primary)
                }

                Text("Enter amount")
                    .font(AppTypography.subheadline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)

            Spacer()
        }
        .padding(.horizontal, AppSpacing.margin)
    } actionBar: {
        Button("Continue") {}
            .buttonStyle(PrimaryButtonStyle())
    }
}

#Preview("WizardLayout — Step 2 (Category Select)") {
    WizardLayout(
        title: "Add Transaction",
        currentStep: 2,
        totalSteps: 3,
        onBack: {},
        onClose: {},
        direction: .trailing
    ) {
        VStack(spacing: AppSpacing.element) {
            Spacer().frame(height: AppSpacing.compact)

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: AppSpacing.compact), count: 3),
                spacing: AppSpacing.compact
            ) {
                ForEach(FC_MockData.categories) { cat in
                    VStack(spacing: AppSpacing.compact) {
                        Circle()
                            .fill(cat.color.opacity(0.1))
                            .frame(width: 56, height: 56)
                            .overlay(
                                Image(systemName: cat.icon)
                                    .font(.system(size: 24))
                                    .foregroundColor(cat.color)
                            )
                        Text(cat.name.components(separatedBy: " ").first ?? cat.name)
                            .font(AppTypography.caption)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                    }
                    .padding(AppSpacing.element)
                    .background(Color.cardBackground)
                    .cornerRadius(AppRadius.medium)
                }
            }
            .padding(.horizontal, AppSpacing.margin)
        }
    } actionBar: {
        VStack(spacing: AppSpacing.compact) {
            Button("Continue") {}
                .buttonStyle(PrimaryButtonStyle())
                .disabled(true)
            Button("Back") {}
                .buttonStyle(SecondaryButtonStyle())
        }
    }
}

#Preview("WizardLayout — Step 3 (Details)") {
    WizardLayout(
        title: "Add Transaction",
        currentStep: 3,
        totalSteps: 3,
        onBack: {},
        onClose: {},
        direction: .trailing
    ) {
        VStack(alignment: .leading, spacing: AppSpacing.element) {
            Spacer().frame(height: AppSpacing.compact)

            // Date row
            HStack {
                IconAvatar(systemName: "calendar", color: .secondary, size: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Date").font(AppTypography.caption).foregroundColor(.secondary)
                    Text("Today, Apr 8").font(AppTypography.body)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(Color(UIColor.tertiaryLabel))
            }
            .padding(AppSpacing.element)
            .background(Color.cardBackground)
            .cornerRadius(AppRadius.medium)

            // Note row
            HStack {
                IconAvatar(systemName: "note.text", color: .secondary, size: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Note (optional)").font(AppTypography.caption).foregroundColor(.secondary)
                    Text("Sweetgreen salad").font(AppTypography.body)
                }
                Spacer()
            }
            .padding(AppSpacing.element)
            .background(Color.cardBackground)
            .cornerRadius(AppRadius.medium)

            // Split row
            HStack {
                IconAvatar(systemName: "person.2.fill", color: .secondary, size: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Split with").font(AppTypography.caption).foregroundColor(.secondary)
                    Text("Not split").font(AppTypography.body).foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(Color(UIColor.tertiaryLabel))
            }
            .padding(AppSpacing.element)
            .background(Color.cardBackground)
            .cornerRadius(AppRadius.medium)
        }
        .padding(.horizontal, AppSpacing.margin)
    } actionBar: {
        VStack(spacing: AppSpacing.compact) {
            Button("Save Transaction") {}
                .buttonStyle(PrimaryButtonStyle())
            Button("Back") {}
                .buttonStyle(SecondaryButtonStyle())
        }
    }
}

#Preview("WizardLayout — Group Creation Step 1") {
    WizardLayout(
        title: "Create Group",
        currentStep: 1,
        totalSteps: 3,
        onBack: nil,
        onClose: {},
        direction: .trailing
    ) {
        VStack(alignment: .leading, spacing: AppSpacing.element) {
            Spacer().frame(height: AppSpacing.compact)

            Text("Group Name")
                .font(AppTypography.headline)
                .padding(.horizontal, AppSpacing.margin)

            // Text field
            HStack {
                TextField("e.g. Hawaii Trip", text: .constant("Hawaii Trip"))
                    .font(AppTypography.body)
                Spacer()
                if !("Hawaii Trip".isEmpty) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Color.themeAccent)
                }
            }
            .padding(AppSpacing.element)
            .background(Color.cardBackground)
            .cornerRadius(AppRadius.medium)
            .padding(.horizontal, AppSpacing.margin)
        }
    } actionBar: {
        Button("Continue") {}
            .buttonStyle(PrimaryButtonStyle())
    }
}
