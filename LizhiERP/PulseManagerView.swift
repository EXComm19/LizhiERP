import SwiftUI
import SwiftData

struct PulseManagerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var subscriptions: [Subscription]
    @Query private var categories: [CategoryEntity]
    
    // Removed duplicate declaration
    
    // Editor Configuration Wrapper for Sheet Identity
    struct SubscriptionEditorConfig: Identifiable {
        let id = UUID()
        let subscription: Subscription?
    }
    
    @State private var editorConfig: SubscriptionEditorConfig?
    // Removed in favor of item binding
    
    // Valid days property removed as Calendar Strip is removed
    
    var body: some View {
        ZStack {
            Color.lizhiBackground.ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Fixed Costs")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.lizhiTextPrimary)
                        
                        Text("Monthly: \(CurrencyService.shared.symbol(for: CurrencyService.shared.baseCurrency))\(String(format: "%.2f", NSDecimalNumber(decimal: monthlyTotal).doubleValue))")
                            .font(.subheadline)
                            .foregroundStyle(Color.lizhiTextSecondary)
                    }
                    
                    Spacer()
                    
                    Button {
                        // Action for View Calendar
                        print("View Calendar Tapped")
                    } label: {
                        Text("Calendar")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(Color.blue)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 20)
                
                // Calendar Strip Removed
                
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
                                    editorConfig = SubscriptionEditorConfig(subscription: sub)
                                    triggerHaptic(.glassTap)
                                }
                                .contextMenu {
                                    Button {
                                        triggerSubscriptionNow(sub)
                                    } label: {
                                        Label("Trigger Now (Test)", systemImage: "play.circle.fill")
                                    }
                                    
                                    Button {
                                        editorConfig = SubscriptionEditorConfig(subscription: sub)
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
                        
                        Spacer().frame(height: 120) // Increased safe area for tab bar
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
        .sheet(item: $editorConfig) { config in
            SubscriptionEditorView(
                isPresented: Binding(
                    get: { editorConfig != nil },
                    set: { if !$0 { editorConfig = nil } }
                ),
                subscriptionToEdit: config.subscription
            )
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
    
    // Helper method `subscriptionsDue` removed
    
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
    
    // Theme Colors
    var cardBackground: Color { Color(red: 28/255, green: 28/255, blue: 30/255) } // Dark Card Background
    
    var brandColor: Color {
        let n = sub.name.lowercased()
        if n.contains("netflix") { return .red }
        if n.contains("spotify") { return .green }
        if n.contains("adobe") { return .red }
        if n.contains("amazon") { return Color(red: 0, green: 0.6, blue: 0.9) } // Light Blue
        if n.contains("icloud") || n.contains("apple") { return .blue }
        if n.contains("youtube") { return .red }
        return sub.type == .income ? .green : .white
    }
    
    var body: some View {
        HStack(spacing: 16) {
                // Attempt to fetch logo via Logo.dev
                let logoURLString = "https://img.logo.dev/\(sub.brandDomain?.isEmpty == false ? sub.brandDomain! : "name/\(sub.name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? "")")?token=pk_EcUNocp3RJOn4qZwg9KGTA&size=200&retina=true"
                
                CachedLogoView(url: URL(string: logoURLString)) {
                    // Fallback / Loading
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(brandColor.opacity(0.1))
                            .frame(width: 48, height: 48)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(brandColor.opacity(0.2), lineWidth: 1)
                            )
                        
                        Image(systemName: categoryIcon)
                            .font(.system(size: 22))
                            .foregroundStyle(brandColor)
                    }
                } content: { image in
                    // Success
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(brandColor.opacity(0.1))
                            .frame(width: 48, height: 48)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(brandColor.opacity(0.2), lineWidth: 1)
                            )
                        
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 48, height: 48) // Fill container
                            .clipShape(RoundedRectangle(cornerRadius: 14)) // Clip to container shape
                    }
                }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(sub.name)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                
                Text("Next bill: \(sub.effectiveNextDate.formatted(.dateTime.month(.abbreviated).day()))")
                    .font(.subheadline)
                    .foregroundStyle(Color.gray)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                // Amount
                Text("\(sub.type == .income ? "+" : "")\(CurrencyService.shared.symbol(for: sub.currency))\(String(format: "%.2f", Double(truncating: sub.amount as NSNumber)))")
                    .font(.title3)
                    .fontWeight(.bold)
                    // Expenses White, Income Green (as per image style)
                    .foregroundStyle(sub.type == .income ? Color.green : Color.white)
                
                // Frequency Pill
                Text(sub.cycle.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.4))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Capsule())
            }
        }
        .padding(20)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}
