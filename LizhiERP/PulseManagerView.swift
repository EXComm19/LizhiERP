import SwiftUI
import SwiftData

struct PulseManagerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var subscriptions: [Subscription]
    @Query private var categories: [CategoryEntity]
    
    @State private var selectedSubscription: Subscription?
    @State private var showEditor = false
    
    // Valid days for calendar strip (mocked relative to today)
    let days: [Date] = (-2...3).map { Calendar.current.date(byAdding: .day, value: $0, to: Date())! }
    
    var body: some View {
        ZStack {
            Color.lizhiBackground.ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 0) {
                // Header: Large Bold Title (Left Aligned) - Consistent with other pages
                HStack {
                    Text("Fixed Costs")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.lizhiTextPrimary)
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 12)
                
                // Calendar Strip - Shows upcoming subscription due dates
                HStack(spacing: 8) {
                    ForEach(days, id: \.self) { day in
                        let dueCount = subscriptionsDue(on: day).count
                        let isToday = Calendar.current.isDateInToday(day)
                        
                        VStack(spacing: 6) {
                            Text(day.formatted(.dateTime.weekday(.abbreviated)))
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundStyle(Color.lizhiTextSecondary)
                            
                            ZStack {
                                Text(day.formatted(.dateTime.day()))
                                    .font(.title3)
                                    .fontWeight(isToday ? .bold : .regular)
                                    .foregroundStyle(isToday ? Color.white : Color.lizhiTextPrimary)
                            }
                            
                            // Subscription due indicator
                            if dueCount > 0 {
                                HStack(spacing: 2) {
                                    Circle()
                                        .fill(dueCount > 0 ? Color.orange : Color.clear)
                                        .frame(width: 6, height: 6)
                                    if dueCount > 1 {
                                        Text("+\(dueCount - 1)")
                                            .font(.system(size: 8, weight: .bold))
                                            .foregroundStyle(Color.orange)
                                    }
                                }
                            } else {
                                Color.clear.frame(height: 6)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(isToday ? Color.blue : Color.lizhiSurface)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(dueCount > 0 && !isToday ? Color.orange.opacity(0.5) : Color.clear, lineWidth: 1.5)
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                
                // Ghost Charge Alert
                if hasGhostCharge {
                    HStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Ghost Charge Detected")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundStyle(Color.lizhiTextPrimary)
                            
                            Text("Spotify was due 2 days ago but no transaction was found.")
                                .font(.caption)
                                .foregroundStyle(Color.lizhiTextSecondary)
                        }
                        
                        Spacer()
                    }
                    .padding()
                    .background(Color.red.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.red.opacity(0.5), lineWidth: 1))
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                }
                
                // Section Header
                Text("RECURRING TRANSACTIONS")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.lizhiTextSecondary)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 8)
                
                // Subscriptions List
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(subscriptions) { sub in
                            SubscriptionRow(sub: sub, categories: categories)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedSubscription = sub
                                    showEditor = true
                                    triggerHaptic(.glassTap)
                                }
                                .contextMenu {
                                    Button {
                                        triggerSubscriptionNow(sub)
                                    } label: {
                                        Label("Trigger Now (Test)", systemImage: "play.circle.fill")
                                    }
                                    
                                    Button {
                                        selectedSubscription = sub
                                        showEditor = true
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    
                                    Button(role: .destructive) {
                                        deleteSubscription(sub)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                        
                        if subscriptions.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "repeat.circle")
                                    .font(.system(size: 60))
                                    .foregroundStyle(Color.lizhiTextSecondary.opacity(0.5))
                                
                                Text("No subscriptions yet")
                                    .font(.headline)
                                    .foregroundStyle(Color.lizhiTextSecondary)
                                
                                Text("Tap + to add your first recurring cost")
                                    .font(.subheadline)
                                    .foregroundStyle(Color.lizhiTextSecondary.opacity(0.7))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 60)
                        }
                        
                        Spacer().frame(height: 100)
                    }
                    .padding(.horizontal, 20)
                }
                
                Spacer().frame(height: 100)
            }
        }
        .sheet(isPresented: $showEditor) {
            SubscriptionEditorView(isPresented: $showEditor, subscriptionToEdit: selectedSubscription)
                .presentationDetents([.large])
        }
        .onAppear {
            print("PulseManagerView appeared. Subscriptions count: \(subscriptions.count)")
            let engine = FinancialEngine(modelContainer: modelContext.container)
            Task { @MainActor in
                await engine.processSubscriptions()
            }
        }
    }
    
    // Check if any subscription is overdue
    var hasGhostCharge: Bool {
        subscriptions.contains { sub in
            sub.nextPaymentDate < Date().addingTimeInterval(-86400 * 2) // 2 days ago
        }
    }
    
    // Convert all subscription costs to base currency before summing
    var monthlyTotal: Decimal {
        subscriptions.reduce(0) { total, sub in
            total + CurrencyService.shared.convertToBase(sub.monthlyCost, from: sub.currency)
        }
    }
    
    /// Find subscriptions due on a specific date
    func subscriptionsDue(on date: Date) -> [Subscription] {
        let calendar = Calendar.current
        return subscriptions.filter { sub in
            // Check if the subscription's due date falls on this day
            calendar.isDate(sub.nextPaymentDate, inSameDayAs: date)
        }
    }
    
    func deleteSubscription(_ sub: Subscription) {
        modelContext.delete(sub)
        triggerHaptic(.glassTap)
    }
    
    /// Test trigger: Creates a transaction from this subscription immediately (for testing)
    func triggerSubscriptionNow(_ sub: Subscription) {
        // Create a Transaction from the subscription (like processSubscriptions does)
        let tx = Transaction(
            amount: sub.amount,
            type: sub.type,
            category: sub.category,
            source: .spending,
            date: Date(),  // Use current date for test
            contextTags: [sub.name, "Test Trigger"],
            categoryName: sub.categoryName,
            subcategory: sub.subcategory,
            linkedAccountID: sub.linkedAccountID,
            currency: sub.currency
        )
        modelContext.insert(tx)
        
        do {
            try modelContext.save()
            triggerHaptic(.hustle)
            print("DEBUG: Test triggered subscription '\(sub.name)' - Transaction created")
        } catch {
            print("DEBUG: Failed to save test transaction: \(error)")
        }
    }
}

struct SubscriptionRow: View {
    let sub: Subscription
    let categories: [CategoryEntity]
    
    // Find icon from category
    var categoryIcon: String {
        if let cat = categories.first(where: { $0.name == sub.categoryName }) {
            return cat.icon
        }
        return sub.type == .income ? "arrow.up.circle.fill" : "arrow.down.circle.fill"
    }
    
    // Color based on type
    var typeColor: Color {
        sub.type == .income ? Color.green : Color.orange
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Circle with category icon
            Circle()
                .fill(typeColor.opacity(0.2))
                .frame(width: 48, height: 48)
                .overlay(
                    Image(systemName: categoryIcon)
                        .font(.title3)
                        .foregroundStyle(typeColor)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(sub.name)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.lizhiTextPrimary)
                
                // Category • Cycle • Next: date
                Text("\(sub.categoryName) • \(sub.cycle) • Next: \(sub.effectiveNextDate.formatted(.dateTime.month(.abbreviated).day()))")
                    .font(.caption)
                    .foregroundStyle(Color.lizhiTextSecondary)
            }
            
            Spacer()
            
            // Price with +/- indicator
            Text("\(sub.type == .income ? "+" : "-")\(CurrencyService.shared.symbol(for: sub.currency))\(String(format: "%.2f", Double(truncating: sub.amount as NSNumber)))")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(typeColor)
        }
        .padding()
        .background(Color.lizhiSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(typeColor.opacity(0.2), lineWidth: 1))
    }
}
