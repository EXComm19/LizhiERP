import SwiftUI
import SwiftData

struct OracleView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var transactions: [Transaction]
    @Query private var assets: [AssetEntity]
    
    @State private var projectedYear: Double = 2026.0 // "Time Slider"
    @State private var forecast: FinancialForecast?
    @State private var isLoadingOracle: Bool = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                Spacer().frame(height: 60)
                
                // Header
                Text("THE ORACLE")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.6))
                    .kerning(4)
                
                // 0. Habits Section
                SpendingHabitsChart(transactions: transactions)
                
                // The Crystal Ball (Main Stat)
                VStack(spacing: 8) {
                    Text("PROJECTED WORTH")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    // Simple logic: Base worth + (Monthly growth * months passed)
                    let yearsPasssed = projectedYear - 2026
                    let estimatedWorth = 142000 + (yearsPasssed * 12 * 5000) // Mock math
                    
                    Text("$\(Int(estimatedWorth))")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, .blue.opacity(0.8)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .contentTransition(.numericText())
                }
                
                // The Nudge Cards (Dynamic)
                if let forecast = forecast {
                    ForEach(forecast.actionableInsights, id: \.self) { insight in
                        HStack(alignment: .top) {
                            Image(systemName: "sparkles")
                                .foregroundStyle(.yellow)
                            Text(insight)
                                .font(.subheadline)
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.leading)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .glassCard()
                    }
                } else if isLoadingOracle {
                     Text("Consulting Gemini...")
                        .shimmering()
                        .padding()
                        .glassCard()
                } else {
                    Button(action: askOracle) {
                        Text("Analyze Strategy")
                            .font(.headline)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .glassCard()
                            .foregroundStyle(.white)
                    }
                }
                
                Spacer()
                
                // The Time Slider
                VStack(alignment: .leading) {
                    Text("FUTURE TIMELINE: \(Int(projectedYear))")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                    
                    Slider(value: $projectedYear, in: 2026...2050, step: 1)
                        .tint(.purple)
                        .onChange(of: projectedYear) { _, _ in
                            triggerHaptic(.glassTap) // Tangible feel
                        }
                }
                .padding()
                .glassCard()
                
                Spacer().frame(height: 100)
            }
            .padding(.horizontal)
        }
    }
    
    func askOracle() {
        isLoadingOracle = true
        Task {
            do {
                let result = try await AIService.shared.generateForecast(transactions: transactions, assets: assets)
                withAnimation {
                    self.forecast = result
                    self.isLoadingOracle = false
                }
            } catch {
                print("Oracle Error: \(error)")
                self.isLoadingOracle = false
            }
        }
    }
}

// MARK: - Spending Habits Chart Component
import Charts

struct SpendingHabitsChart: View {
    var transactions: [Transaction]
    
    // Drill Down State
    @State private var selectedCategory: TransactionCategory?
    
    // Data Models
    struct ChartSegment: Identifiable {
        let id = UUID()
        let label: String
        let value: Double
        let color: Color
        let category: TransactionCategory? // For linking back
    }
    
    var expenses: [Transaction] {
        transactions.filter { $0.type == .expense }
    }
    
    var totalExpense: Double {
        expenses.reduce(0) { $0 + Double(truncating: $1.amount as NSNumber) }
    }
    
    var chartData: [ChartSegment] {
        if let category = selectedCategory {
            // Drill Down: Show Subcategories for selected Category
            let catExpenses = expenses.filter { $0.category == category }
            let grouped = Dictionary(grouping: catExpenses, by: { $0.subcategory.isEmpty ? "Other" : $0.subcategory })
            
            return grouped.map { (key, txs) in
                let sum = txs.reduce(0) { $0 + Double(truncating: $1.amount as NSNumber) }
                return ChartSegment(label: key, value: sum, color: categoryColor(category).opacity(0.8), category: nil)
            }.sorted(by: { $0.value > $1.value })
            
        } else {
            // Top Level: Show Categories
            let grouped = Dictionary(grouping: expenses, by: { $0.category })
            
            return grouped.compactMap { (cat, txs) -> ChartSegment? in
                if cat == .investment { return nil } // Exclude investment from "Spending" habits usually? Or keep it. Let's keep specific spending cats.
                let sum = txs.reduce(0) { $0 + Double(truncating: $1.amount as NSNumber) }
                return ChartSegment(label: cat.rawValue, value: sum, color: categoryColor(cat), category: cat)
            }.sorted(by: { $0.value > $1.value })
        }
    }
    
    var displayTotal: Double {
        if let category = selectedCategory {
            return expenses.filter { $0.category == category }.reduce(0) { $0 + Double(truncating: $1.amount as NSNumber) }
        } else {
            return totalExpense
        }
    }
    
    func categoryColor(_ cat: TransactionCategory) -> Color {
        switch cat {
        case .survival: return Color.blue
        case .material: return Color.purple
        case .experiential: return Color(hex: "FF4081") // Pink
        case .investment: return Color.green
        case .uncategorized: return Color.gray
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                if selectedCategory != nil {
                    Button {
                        withAnimation { selectedCategory = nil }
                    } label: {
                        Image(systemName: "arrow.left")
                            .font(.headline)
                            .foregroundStyle(.white)
                    }
                }
                
                Image(systemName: "chart.pie.fill")
                    .foregroundStyle(.blue)
                Text(selectedCategory?.rawValue ?? "Habits")
                    .font(.headline)
                    .foregroundStyle(.white)
            }
            .padding(.horizontal)
            
            HStack(spacing: 24) {
                // Chart
                ZStack {
                    Chart(chartData) { segment in
                        SectorMark(
                            angle: .value("Amount", segment.value),
                            innerRadius: .ratio(0.65),
                            outerRadius: .ratio(1.0),
                            angularInset: 2.0
                        )
                        .foregroundStyle(segment.color)
                        .cornerRadius(4)
                    }
                    .frame(width: 140, height: 140)
                    
                    // Center Text
                    VStack(spacing: 2) {
                        Text("TOTAL")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.gray)
                        Text("$\(displayTotal.formatted(.number.precision(.fractionLength(2))))")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                
                // Legend
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(chartData.prefix(4)) { segment in // Show top 4
                        Button {
                            if let cat = segment.category {
                                withAnimation { selectedCategory = cat }
                            }
                        } label: {
                            HStack {
                                Circle().fill(segment.color).frame(width: 8, height: 8)
                                Text(segment.label)
                                    .font(.caption)
                                    .foregroundStyle(.white)
                                Spacer()
                                VStack(alignment: .trailing) {
                                    Text("$\(segment.value.formatted(.number.precision(.fractionLength(2))))")
                                        .font(.caption.bold())
                                        .foregroundStyle(.white)
                                    Text("\(Int((segment.value / displayTotal) * 100))%")
                                        .font(.system(size: 9))
                                        .foregroundStyle(.gray)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .padding()
            .background(Color(hex: "1A1A1A"))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(.white.opacity(0.1), lineWidth: 1)
            )
            .padding(.horizontal)
        }
        .padding(.top, 10)
    }
}

// Keep the Shimmer Effect helper
extension View {
    func shimmering() -> some View {
        self.modifier(ShimmerEffect())
    }
}

struct ShimmerEffect: ViewModifier {
    @State private var phase: CGFloat = 0
    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    Rectangle()
                        .fill(LinearGradient(colors: [.clear, .white.opacity(0.4), .clear], startPoint: .leading, endPoint: .trailing))
                        .rotationEffect(.degrees(30))
                        .offset(x: -geo.size.width + (geo.size.width * 2 * phase))
                }
            )
            .mask(content)
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) { phase = 1 }
            }
    }
}

#Preview {
    OracleView()
        .modelContainer(for: [Transaction.self, AssetEntity.self], inMemory: true)
        .preferredColorScheme(.dark)
}
