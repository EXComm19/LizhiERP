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
                // Header: PULSE MANAGER + Back Button
                HStack {
                    Button {
                        dismiss()
                        triggerHaptic(.glassTap)
                    } label: {
                        Image(systemName: "arrow.left.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Color.lizhiTextPrimary)
                    }
                    
                    Spacer()
                    
                    Text("PULSE MANAGER")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.lizhiTextSecondary)
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                
                // Large Title
                Text("Fixed Costs")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.lizhiTextPrimary)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                
                // Calendar Strip
                HStack(spacing: 12) {
                    ForEach(days, id: \.self) { day in
                        VStack(spacing: 4) {
                            Text(day.formatted(.dateTime.weekday(.abbreviated)))
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(Color.lizhiTextSecondary)
                            
                            Text(day.formatted(.dateTime.day()))
                                .font(.title3)
                                .fontWeight(Calendar.current.isDateInToday(day) ? .bold : .regular)
                                .foregroundStyle(Calendar.current.isDateInToday(day) ? Color.white : Color.lizhiTextPrimary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            Calendar.current.isDateInToday(day) ?
                            Color.blue : Color.lizhiSurface
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
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
                Text("ACTIVE SUBSCRIPTIONS")
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
                            SubscriptionRow(sub: sub)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedSubscription = sub
                                    showEditor = true
                                    triggerHaptic(.glassTap)
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
                
                Spacer()
            }
            
            // Bottom Toolbar
            VStack {
                Spacer()
                
                HStack(spacing: 40) {
                    Button {
                        // Refresh/Sync
                        let engine = FinancialEngine(modelContainer: modelContext.container)
                        Task { @MainActor in
                            await engine.processSubscriptions()
                        }
                        triggerHaptic(.glassTap)
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.title2)
                            .foregroundStyle(Color.lizhiTextPrimary)
                    }
                    
                    Button {
                        // Archive/Manage
                        triggerHaptic(.glassTap)
                    } label: {
                        Image(systemName: "archivebox")
                            .font(.title2)
                            .foregroundStyle(Color.lizhiTextPrimary)
                    }
                    
                    Button {
                        // Layers/Categories
                        triggerHaptic(.glassTap)
                    } label: {
                        Image(systemName: "square.stack.3d.up")
                            .font(.title2)
                            .foregroundStyle(Color.lizhiTextPrimary)
                    }
                    
                    Button {
                        selectedSubscription = nil
                        showEditor = true
                        triggerHaptic(.glassTap)
                    } label: {
                        Circle()
                            .fill(Color.lizhiTextPrimary)
                            .frame(width: 56, height: 56)
                            .overlay(
                                Image(systemName: "plus")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundStyle(Color.lizhiBackground)
                            )
                    }
                }
                .padding()
                .background(
                    Color.lizhiSurface
                        .overlay(.ultraThinMaterial)
                )
                .clipShape(RoundedRectangle(cornerRadius: 30))
                .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
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
            sub.firstBillDate < Date().addingTimeInterval(-86400 * 2) // 2 days ago
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
