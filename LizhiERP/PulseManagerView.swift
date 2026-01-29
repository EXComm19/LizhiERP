import SwiftUI
import SwiftData

struct PulseManagerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var subscriptions: [Subscription]
    
    @State private var selectedSubscription: Subscription?
    @State private var showEditor = false
    
    // Valid days for calendar strip (mocked relative to today)
    let days: [Date] = (-2...3).map { Calendar.current.date(byAdding: .day, value: $0, to: Date())! }
    
    var body: some View {
        ZStack {
            Color.lizhiBackground.ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 0) {
                // Header: Large Bold Title (Left Aligned)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Fixed Costs")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.lizhiTextPrimary)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 16)
                
                // Summary Card: Blue Gradient
                VStack(spacing: 8) {
                    Text("Monthly Recurring")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.white.opacity(0.8))
                    
                    Text("\(CurrencyService.shared.symbol(for: CurrencyService.shared.baseCurrency))\(String(format: "%.2f", NSDecimalNumber(decimal: monthlyTotal).doubleValue))")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background(
                    LinearGradient(
                        colors: [Color(hex: "1E3A5F"), Color(hex: "2A5298")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.blue.opacity(0.3), lineWidth: 2))
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
                
                // Subscriptions List
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(subscriptions) { sub in
                            SubscriptionRow(sub: sub)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedSubscription = sub
                                    showEditor = true
                                    triggerHaptic(.glassTap)
                                }
                        }
                        
                        if subscriptions.isEmpty {
                            Text("No subscriptions yet")
                                .font(.subheadline)
                                .foregroundStyle(Color.lizhiTextSecondary)
                                .padding(.top, 40)
                        }
                        
                        Spacer().frame(height: 120)
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
        .sheet(isPresented: $showEditor) {
            SubscriptionEditorView(isPresented: $showEditor, subscriptionToEdit: selectedSubscription)
                .presentationDetents([.fraction(0.8)])
        }
        .onAppear {
            print("PulseManagerView appeared. Subscriptions count: \(subscriptions.count)")
            let engine = FinancialEngine(modelContainer: modelContext.container)
            Task { @MainActor in
                await engine.processSubscriptions()
            }
        }
    }
    
    // Convert all subscription costs to base currency before summing
    var monthlyTotal: Decimal {
        subscriptions.reduce(0) { total, sub in
            total + CurrencyService.shared.convertToBase(sub.monthlyCost, from: sub.currency)
        }
    }
    
    func deleteSubscription(_ sub: Subscription) {
        modelContext.delete(sub)
        triggerHaptic(.glassTap)
    }
}

struct SubscriptionRow: View {
    let sub: Subscription
    
    var body: some View {
        HStack(spacing: 16) {
            // Circle with first letter
            Circle()
                .fill(Color.white)
                .frame(width: 48, height: 48)
                .overlay(
                    Text(String(sub.name.prefix(1)).uppercased())
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(.black)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(sub.name)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.lizhiTextPrimary)
                
                // Cycle • Next: date
                Text("\(sub.cycle.capitalized) • Next: \(sub.firstBillDate.formatted(.dateTime.year().month().day()))")
                    .font(.caption)
                    .foregroundStyle(Color.lizhiTextSecondary)
            }
            
            Spacer()
            
            // Price
            Text("\(CurrencyService.shared.symbol(for: sub.currency))\(String(format: "%.2f", Double(truncating: sub.amount as NSNumber)))")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(Color.lizhiTextPrimary)
        }
        .padding()
        .background(Color.lizhiSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.lizhiTextSecondary.opacity(0.1), lineWidth: 1))
    }
}
