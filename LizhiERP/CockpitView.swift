import SwiftUI
import SwiftData

struct CockpitView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Transaction.date, order: .reverse) private var allTransactions: [Transaction]
    @Query private var assets: [AssetEntity]
    
    @State private var financialEngine: FinancialEngine?
    
    // Metrics
    @State private var activeIncome: Double = 0.0
    @State private var totalBurn: Double = 0.0
    
    // Spending Habits
    @State private var survivalSpend: Double = 0.0
    @State private var materialSpend: Double = 0.0
    @State private var experientialSpend: Double = 0.0
    
    // AI Insights
    @State private var aiInsight: String = "Analyzing your financial dna..."
    @State private var isLoadingAI: Bool = false
    @State private var showSettings = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("GOOD MORNING")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(.secondary)
                            .kerning(1.0)
                        Text("Lizhi")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundStyle(.primary)
                    }
                    Spacer()
                    Button {
                        showSettings = true
                    } label: {
                        Circle()
                            .fill(Color(uiColor: .secondarySystemBackground))
                            .frame(width: 44, height: 44)
                            .overlay {
                                Text("L")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.primary)
                            }
                    }
                }
                .padding(.horizontal)
                .sheet(isPresented: $showSettings) {
                    SettingsView()
                }
                
                // 2. Metrics Cards
                HStack(spacing: 16) {
                    // Burn Card: Dark Red/Brown Gradient
                    MetricCard(
                        title: "Monthly Burn",
                        value: totalBurn,
                        gradientColors: [Color(hex: "5A2D2D"), Color(hex: "2A1515")]
                    )
                    
                    // Income Card: Dark Teal/Green Gradient
                    MetricCard(
                        title: "Income",
                        value: activeIncome,
                        gradientColors: [Color(hex: "1F4E4E"), Color(hex: "0F2626")]
                    )
                }
                .frame(height: 140) // Taller cards as per design
                
                // 3. Spending Habits
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        Image(systemName: "chart.pie.fill")
                            .foregroundStyle(Color(hex: "A084E8")) // Light Purple Icon
                        Text("Spending Habits")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                    }
                    
                    // Segmented Bar
                    GeometryReader { geo in
                        HStack(spacing: 0) {
                            let total = survivalSpend + materialSpend + experientialSpend
                            if total > 0 {
                                Rectangle().fill(Color(hex: "5D9CFF")).frame(width: geo.size.width * (survivalSpend / total)) // Blue
                                Rectangle().fill(Color(hex: "B589FF")).frame(width: geo.size.width * (materialSpend / total)) // Purple
                                Rectangle().fill(Color(hex: "FF7EB3")).frame(width: geo.size.width * (experientialSpend / total)) // Pink
                            } else {
                                Rectangle().fill(Color.gray.opacity(0.3)).frame(width: geo.size.width)
                            }
                        }
                    }
                    .frame(height: 16)
                    .clipShape(Capsule())
                    
                    // Legend
                    HStack(spacing: 24) { // Wider spacing
                        LegendItem(color: Color(hex: "5D9CFF"), label: "Survival")
                        LegendItem(color: Color(hex: "B589FF"), label: "Material")
                        LegendItem(color: Color(hex: "FF7EB3"), label: "Experiential")
                    }
                }
                .padding(24)
                .background(Color(hex: "151515")) // Dark Gray BG
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.1), lineWidth: 1))
                
                // 4. AI Insights
                VStack(alignment: .leading, spacing: 0) {
                    Text("AI Insights")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.bottom, 12)
                    
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(alignment: .top, spacing: 16) {
                            Image(systemName: "sparkles")
                                .foregroundStyle(.yellow)
                                .font(.title2)
                            
                            Text(aiInsight)
                                .font(.subheadline) // Slightly larger
                                .foregroundStyle(.white.opacity(0.95))
                                .lineSpacing(6)
                                .fixedSize(horizontal: false, vertical: true)
                                .redacted(reason: isLoadingAI ? .placeholder : [])
                        }
                        
                        Divider().background(Color.white.opacity(0.1))
                        
                        Text("Based on \(allTransactions.count) records")
                            .font(.caption)
                            .foregroundStyle(.gray)
                    }
                    .padding(24)
                    .background(Color(hex: "151515"))
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.1), lineWidth: 1))
                }
                
                // Bottom Spacer
                Spacer().frame(height: 100)
            }
            .padding(.horizontal, 20)
        }
        .background(Color.black.ignoresSafeArea())
        .onAppear {
            financialEngine = FinancialEngine(modelContainer: modelContext.container)
            refreshData()
        }
    }
    
    func refreshData() {
        Task {
            guard let engine = financialEngine else { return }
            let metrics = await engine.calculateMonthlyMetrics()
            
            // Spending Habits Breakdown
            let calendar = Calendar.current
            let thisMonthTxs = allTransactions.filter { calendar.isDate($0.date, equalTo: Date(), toGranularity: .month) }
            
            let survival = thisMonthTxs.filter { $0.category == .survival && $0.type == .expense }.reduce(0) { $0 + $1.amount }
            let material = thisMonthTxs.filter { $0.category == .material && $0.type == .expense }.reduce(0) { $0 + $1.amount }
            let experiential = thisMonthTxs.filter { $0.category == .experiential && $0.type == .expense }.reduce(0) { $0 + $1.amount }
            
            withAnimation(.spring) {
                self.activeIncome = metrics.activeIncome
                self.totalBurn = metrics.totalBurn
                self.survivalSpend = NSDecimalNumber(decimal: survival).doubleValue
                self.materialSpend = NSDecimalNumber(decimal: material).doubleValue
                self.experientialSpend = NSDecimalNumber(decimal: experiential).doubleValue
            }
            
            // Fetch AI
            if !isLoadingAI && !allTransactions.isEmpty {
                await fetchAI()
            } else if allTransactions.isEmpty {
                 self.aiInsight = "Add some transaction records to unlock AI insights."
            }
        }
    }
    
    func fetchAI() async {
        isLoadingAI = true
        do {
            let forecast = try await AIService.shared.generateForecast(transactions: Array(allTransactions.prefix(50)), assets: assets)
            withAnimation {
                self.aiInsight = forecast.actionableInsights.first ?? "Your spending is on track. Keep hustling!"
                isLoadingAI = false
            }
        } catch {
             print("AI Error: \(error)")
             withAnimation {
                 self.aiInsight = "Oracle is meditating. Try again later."
                 isLoadingAI = false
             }
        }
    }
}

// Components

struct MetricCard: View {
    let title: String
    let value: Double
    let gradientColors: [Color]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundStyle(.white.opacity(0.8))
            
            Spacer()
            
            Text("$\(Int(value).formattedWithSeparator)")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .overlay(RoundedRectangle(cornerRadius: 28).stroke(Color.white.opacity(0.1), lineWidth: 1))
    }
}

struct LegendItem: View {
    let color: Color
    let label: String
    
    var body: some View {
        HStack(spacing: 8) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.gray)
        }
    }
}

#Preview {
    CockpitView()
        .preferredColorScheme(.dark)
}
