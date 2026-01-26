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
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header (Kept outside List for sticky feel, or put in List section header?)
                // Let's keep Header static on top
                HStack {
                    VStack(alignment: .leading) {
                        Text("PULSE MANAGER")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(.gray)
                        Text("Fixed Costs")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                    }
                    
                    Spacer()
                    
                    Button {
                        dismiss()
                    } label: {
                        Circle()
                            .fill(Color(hex: "2A2A2A"))
                            .frame(width: 44, height: 44)
                            .overlay(Image(systemName: "arrow.left").foregroundStyle(.white))
                    }
                }
                .padding()

                
                List {
                    // 1. Calendar Strip Section
                    Section {
                        HStack(spacing: 0) {
                            ForEach(0..<6, id: \.self) { i in
                                let date = Calendar.current.date(byAdding: .day, value: i - 2, to: Date())!
                                let isToday = Calendar.current.isDateInToday(date)
                                
                                VStack(spacing: 8) {
                                    Text(date.formatted(.dateTime.weekday()))
                                        .font(.caption)
                                        .foregroundStyle(.gray)
                                    
                                    Text(date.formatted(.dateTime.day()))
                                        .font(.title3)
                                        .fontWeight(.bold)
                                        .foregroundStyle(isToday ? .white : .gray)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    isToday
                                    ? Circle().fill(Color.blue).opacity(0.8).frame(width: 40, height: 40).offset(y: 8)
                                    : nil
                                )
                            }
                        }
                        .padding()
                        .background(Color(hex: "111111"))
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                    }
                    .listRowInsets(EdgeInsets()) // Edge to edge
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    
                    // 2. Subscriptions Section
                    Section {
                        if subscriptions.isEmpty {
                            Text("No subscriptions active")
                                .font(.caption)
                                .foregroundStyle(.gray)
                                .padding(.top, 40)
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                        } else {
                            ForEach(subscriptions) { sub in
                                SubscriptionRow(sub: sub)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        selectedSubscription = sub
                                        showEditor = true
                                        triggerHaptic(.glassTap)
                                    }
                                    .swipeActions(edge: .trailing) {
                                        Button(role: .destructive) {
                                            deleteSubscription(sub)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                            }
                        }
                    } header: {
                        HStack {
                            Text("ACTIVE SUBSCRIPTIONS (\(subscriptions.count))")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundStyle(.gray)
                                .kerning(1.2)
                            Spacer()
                            Text("Total: $\(Int(NSDecimalNumber(decimal: monthlyTotal).doubleValue))/mo")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        .padding(.vertical, 8)
                    }
                    .listSectionSeparator(.hidden)
                    
                    // 3. Add Button Section (Removed as moved to FAB)
                    Section {
                         Spacer().frame(height: 100)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .sheet(isPresented: $showEditor) {
            SubscriptionEditorView(isPresented: $showEditor, subscriptionToEdit: selectedSubscription)
                .presentationDetents([.fraction(0.8)])
        }
        .onAppear {
            // Process any due subscriptions
            print("PulseManagerView appeared. Subscriptions count: \(subscriptions.count)")
            let engine = FinancialEngine(modelContainer: modelContext.container)
            Task { @MainActor in
                await engine.processSubscriptions()
            }
        }
    }
    
    var monthlyTotal: Decimal {
        subscriptions.reduce(0) { $0 + $1.monthlyCost }
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
            Circle()
                .fill(Color.white)
                .frame(width: 48, height: 48)
                .overlay(
                    Image(systemName: sub.icon)
                        .foregroundStyle(.black)
                        .font(.title3)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(sub.name)
                    .font(.headline)
                    .foregroundStyle(.white)
                Text("Next Bill: \(sub.firstBillDate.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundStyle(.gray)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("$\(Double(truncating: sub.amount as NSNumber), specifier: "%.2f")")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                Text(sub.cycle.uppercased())
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(.gray)
            }
        }
        .padding()
        .background(Color(hex: "1A1A1A"))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.1), lineWidth: 1))
    }
}
