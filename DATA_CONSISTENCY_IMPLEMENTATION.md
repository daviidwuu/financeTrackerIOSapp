# Data Denormalization Fix - Implementation Plan

## Executive Summary
Eliminate denormalized data stored in 10+ places (names, categories, user details) by establishing single sources of truth with reactive updates.

## Problem
- User/Payee/Category names duplicated across Transaction, DebtPayment, SocialTransaction, etc.
- Changing a category name requires updates in multiple models
- High inconsistency risk and bugs

## Solution Architecture
- Create immutable reference models (UserReference, PayeeReference, CategoryReference)
- Use dependency injection for managers (UserManager, CategoryManager)
- Implement reactive updates via protocol observers
- Keep only IDs in transaction objects; fetch names on-demand or via computed properties

## Key Files to Modify
- `Models/Transaction.swift` - Replace name strings with references
- `Models/DebtPayment.swift` - Same denormalization fix
- `Models/SocialTransaction.swift` - Same denormalization fix
- `Managers/UserManager.swift` - New central authority
- `Managers/CategoryManager.swift` - New central authority
- Update all views to fetch names from managers instead of models

## Implementation Steps
1. Create Reference types (PayeeReference, CategoryReference)
2. Create immutable manager protocols
3. Update Transaction/DebtPayment/SocialTransaction models
4. Update all views (HomeView, TransactionListView, ReportView)
5. Add unit tests for reference consistency

## Estimated Effort
- Small scope: 4-6 hours
- Low breaking changes: Mostly internal restructuring
- High impact: Prevents future consistency bugs

## Testing Strategy
- Verify single source of truth for each entity
- Test name updates cascade correctly
- Validate no duplicate data exists in models
