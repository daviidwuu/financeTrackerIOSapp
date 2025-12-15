import SwiftUI

struct HomeView: View {
    @Environment(\.colorScheme) var colorScheme
    @State private var showAddTransaction = false
    @State private var showProfile = false
    @State private var transactionToEdit: Transaction?
    @State private var showRemainingBudget = false
    
    let monthlyBudget = 5000.0
    let totalSpent = 4250.0
    
    @State private var transactions: [Transaction] = [
        Transaction(title: "Apple Music", subtitle: "Subscription", amount: "-$9.99", icon: "music.note", color: .pink),
        Transaction(title: "Uber", subtitle: "Transport", amount: "-$24.50", icon: "car.fill", color: .black),
        Transaction(title: "Salary", subtitle: "Income", amount: "+$3,200.00", icon: "dollarsign.circle.fill", color: .green)
    ]
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                List {
                    // Section 1: Header & Balance
                    Section {
                        VStack(spacing: 24) {
                            // Custom Header
                            HStack(alignment: .bottom) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Welcome")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.secondary)
                                    Text("David")
                                        .font(.system(size: 34, weight: .bold, design: .rounded))
                                        .foregroundColor(.primary)
                                }
                                
                                Spacer()
                                
                                Button(action: { showProfile = true }) {
                                    Circle()
                                        .fill(Color.secondary.opacity(0.15))
                                        .frame(width: 44, height: 44)
                                        .overlay(
                                            Image(systemName: "person.fill")
                                                .font(.system(size: 20))
                                                .foregroundColor(.primary)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.top, 10)
                            
                            // Balance Card
                            VStack(alignment: .leading, spacing: 20) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Balance")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.secondary)
                                    
                                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                                        Text(showRemainingBudget ? "$\(String(format: "%.2f", monthlyBudget - totalSpent))" : "$\(String(format: "%.2f", totalSpent))")
                                            .font(.system(size: 42, weight: .bold, design: .rounded))
                                            .foregroundColor(.primary)
                                            .contentTransition(.numericText())
                                        Text(showRemainingBudget ? "left" : "spent")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                            .transition(.opacity)
                                    }
                                    .onTapGesture {
                                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                            showRemainingBudget.toggle()
                                        }
                                    }
                                }
                                
                                // Custom Pill-Shaped Progress Bar
                                GeometryReader { geometry in
                                    ZStack(alignment: .leading) {
                                        Capsule()
                                            .fill(Color.secondary.opacity(0.15))
                                            .frame(height: 24)
                                        
                                        Capsule()
                                            .fill(Color.primary)
                                            .frame(width: geometry.size.width * 0.35, height: 24)
                                    }
                                }
                                .frame(height: 24)
                                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                            }
                            .padding(24)
                            .background(Color(uiColor: .secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 28))
                        }
                        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .padding(.bottom, 20)
                    }
                    
                    // Section 2: Recent Transactions
                    Section(header: Text("Recent Transactions").font(.title2).fontWeight(.bold).foregroundColor(.primary)) {
                        ForEach(transactions) { transaction in
                            TransactionRow(transaction: transaction)
                                .background(Color(uiColor: .secondarySystemBackground))
                                .cornerRadius(16)
                                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                                .padding(.bottom, 8)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        if let index = transactions.firstIndex(where: { $0.id == transaction.id }) {
                                            transactions.remove(at: index)
                                        }
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                    Button {
                                        transactionToEdit = transaction
                                        showAddTransaction = true
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    .tint(.blue)
                                }
                        }
                    }
                    .listRowBackground(Color.clear)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .scrollIndicators(.hidden)
                
                // Floating Action Button
                Button(action: {
                    transactionToEdit = nil
                    showAddTransaction = true
                }) {
                    Circle()
                        .fill(Color.primary)
                        .frame(width: 56, height: 56)
                        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                        .overlay(
                            Image(systemName: "plus")
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundColor(colorScheme == .dark ? .black : .white)
                        )
                }
                .padding(.trailing, 20)
                .padding(.bottom, 20)
                .sheet(isPresented: $showAddTransaction) {
                    AddTransactionView(transactionToEdit: transactionToEdit, onSave: { updatedTransaction in
                        if let index = transactions.firstIndex(where: { $0.id == updatedTransaction.id }) {
                            transactions[index] = updatedTransaction
                        } else {
                            transactions.insert(updatedTransaction, at: 0)
                        }
                    })
                    .presentationDetents([.fraction(0.55)])
                    .presentationDragIndicator(.visible)
                }
                .sheet(isPresented: $showProfile) {
                    ProfileView()
                }
            }
            .navigationBarHidden(true)
        }
    }
}

struct TransactionRow: View {
    let transaction: Transaction
    
    var body: some View {
        HStack(spacing: 16) {
            Circle()
                .fill(transaction.color.opacity(0.1))
                .frame(width: 48, height: 48)
                .overlay(
                    Image(systemName: transaction.icon)
                        .font(.system(size: 20))
                        .foregroundColor(transaction.color)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.title)
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                Text(transaction.subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(transaction.amount)
                .font(.system(.callout, design: .rounded))
                .fontWeight(.bold)
                .foregroundColor(transaction.amount.hasPrefix("+") ? .green : .primary)
        }
        .padding(16)
    }
}

#Preview {
    HomeView()
}
