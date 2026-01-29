import SwiftUI
import SwiftData
import Charts

struct CockpitView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Transaction.date, order: .reverse) private var allTransactions: [Transaction]
    @Query private var assets: [AssetEntity]
    @Query private var categories: [CategoryEntity]
    
    @State private var financialEngine: FinancialEngine?
    
    // Metrics
    @State private var activeIncome: Double = 0.0
    @State private var totalBurn: Double = 0.0
    
    // Spending Habits (High-Level)
    @State private var survivalSpend: Double = 0.0
    @State private var materialSpend: Double = 0.0
    @State private var experientialSpend: Double = 0.0
    @State private var investmentSpend: Double = 0.0
    @State private var uncategorizedSpend: Double = 0.0
    
    // Subcategory Breakdown (For Pie Chart - e.g., Food, Transport, Entertainment)
    @State private var subcategoryBreakdown: [String: Double] = [:]
    
    // AI Insights (Persisted to save tokens)
    @AppStorage("strategicInsight") private var strategicIdea: String = "Analyzing big picture..."
    @AppStorage("tacticalInsight") private var tacticalIdea: String = "Finding quick wins..."
    @AppStorage("lastAnalyzedCount") private var lastAnalyzedCount: Int = 0
    
    @State private var isLoadingAI: Bool = false
    @State private var showSettings = false
    
    // UI State
    @State private var displayMonth: String = "This Month"
    @State private var selectedPeriod: Calendar.Component = .month
    @State private var selectedDate: Date = Date()
    @State private var isFirstLoad = true
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerSection
                
                metricsSection
                
                habitsSection
                
                categoryBreakdownSection
                
                aiInsightsSection
                
                // Bottom Spacer
                Spacer().frame(height: 100)
            }
            .padding(.horizontal, 20)
        }
        .background(Color.lizhiBackground.ignoresSafeArea())
        .onAppear {
            financialEngine = FinancialEngine(modelContainer: modelContext.container)
            refreshData()
        }
        .onChange(of: allTransactions) { _, _ in
            refreshData()
        }
    }
    
    // Sub-views to calm down the compiler
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
                // Top Row: Greeting + Profile
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("GOOD MORNING")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.lizhiTextSecondary)
                            .kerning(1.0)
                        Text("Lizhi")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundStyle(Color.lizhiTextPrimary)
                    }
                    Spacer()
                    
                    // Manual Refresh
                    Button {
                        refreshData(forceAI: true) // Force refresh AI
                        triggerHaptic(.glassTap)
                    } label: {
                        Circle()
                            .fill(Color.lizhiSurface)
                            .frame(width: 44, height: 44)
                            .overlay {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.headline)
                                    .foregroundStyle(Color.lizhiTextPrimary)
                            }
                    }
                    
                    Button {
                        showSettings = true
                    } label: {
                        Circle()
                            .fill(Color.lizhiSurface)
                            .frame(width: 44, height: 44)
                            .overlay {
                                Text("L")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .foregroundStyle(Color.lizhiTextPrimary)
                            }
                    }
                }
                
                // Bottom Row: Date Filter
                HStack(spacing: 12) {
                    // Period Picker
                    Picker("Period", selection: $selectedPeriod) {
                        Text("Month").tag(Calendar.Component.month)
                        Text("Year").tag(Calendar.Component.year)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 120)
                    .onChange(of: selectedPeriod) { _, _ in refreshData() }
                    
                    // Date Navigator
                    HStack {
                        Button {
                            moveDate(by: -1)
                        } label: {
                            Image(systemName: "chevron.left")
                                .foregroundStyle(Color.lizhiTextSecondary)
                                .padding(8)
                        }
                        
                        Spacer()
                        
                        Text(formatSelectedDate())
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.lizhiTextPrimary)
                            .onTapGesture {
                                // Reset to Latest/Current on tap
                                selectedDate = allTransactions.first?.date ?? Date()
                                refreshData()
                                triggerHaptic(.glassTap)
                            }
                        
                        Spacer()
                        
                        Button {
                            moveDate(by: 1)
                        } label: {
                            Image(systemName: "chevron.right")
                                .foregroundStyle(Color.lizhiTextSecondary)
                                .padding(8)
                        }
                    }
                    .background(Color.lizhiSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        .padding(.horizontal)
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }
    
    private var metricsSection: some View {
        HStack(spacing: 16) {
            // Burn Card
            MetricCard(
                title: "Burn (\(displayMonth))",
                value: totalBurn,
                type: .burn
            )
            
            // Income Card
            MetricCard(
                title: "Income",
                value: activeIncome,
                type: .income
            )
        }
        .frame(height: 140) // Taller cards as per design
    }
    
    private var habitsSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Image(systemName: "chart.pie.fill")
                    .foregroundStyle(Color(hex: "A084E8")) // Light Purple Icon
                Text("Spending Habits")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.lizhiTextPrimary)
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
        .background(Color.lizhiSurface) // Adaptive Surface
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.lizhiTextSecondary.opacity(0.1), lineWidth: 1))
    }
    
    // Pie Chart Data Model
    struct CategorySpend: Identifiable {
        let id = UUID()
        let category: String
        let amount: Double
        let color: Color
    }
    
    // Color palette for subcategories
    private let subcategoryColors: [Color] = [
        Color(hex: "5D9CFF"), // Blue
        Color(hex: "B589FF"), // Purple
        Color(hex: "FF7EB3"), // Pink
        Color(hex: "4ADE80"), // Green
        Color(hex: "FBBF24"), // Yellow
        Color(hex: "F97316"), // Orange
        Color(hex: "06B6D4"), // Cyan
        Color(hex: "EC4899"), // Magenta
        Color(hex: "8B5CF6"), // Violet
        Color(hex: "94A3B8"), // Slate (for "Other")
    ]
    
    private var categoryData: [CategorySpend] {
        // Sort by amount descending, limit to top 8 + "Other"
        let sorted = subcategoryBreakdown.sorted { $0.value > $1.value }
        var data: [CategorySpend] = []
        var othersTotal: Double = 0
        
        for (index, item) in sorted.enumerated() {
            if index < 8 {
                let color = subcategoryColors[index % subcategoryColors.count]
                data.append(CategorySpend(category: item.key, amount: item.value, color: color))
            } else {
                othersTotal += item.value
            }
        }
        
        // Add "Others" if there are more than 8 categories
        if othersTotal > 0 {
            data.append(CategorySpend(category: "Others", amount: othersTotal, color: subcategoryColors.last!))
        }
        
        return data
    }
    
    private var categoryBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Image(systemName: "chart.pie.fill")
                    .foregroundStyle(Color(hex: "FF7EB3"))
                Text("Category Breakdown")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.lizhiTextPrimary)
            }
            
            if categoryData.isEmpty {
                Text("No spending data yet")
                    .font(.subheadline)
                    .foregroundStyle(Color.lizhiTextSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 40)
            } else {
                HStack(alignment: .center, spacing: 24) {
                    // Pie Chart
                    Chart(categoryData) { item in
                        SectorMark(
                            angle: .value("Amount", item.amount),
                            innerRadius: .ratio(0.5),
                            angularInset: 2
                        )
                        .foregroundStyle(item.color)
                        .cornerRadius(4)
                    }
                    .frame(width: 140, height: 140)
                    
                    // Legend with amounts
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(categoryData) { item in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(item.color)
                                    .frame(width: 10, height: 10)
                                Text(item.category)
                                    .font(.caption)
                                    .foregroundStyle(Color.lizhiTextSecondary)
                                Spacer()
                                Text("\(CurrencyService.shared.symbol(for: CurrencyService.shared.baseCurrency))\(Int(item.amount).formattedWithSeparator)")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundStyle(Color.lizhiTextPrimary)
                            }
                        }
                    }
                }
            }
        }
        .padding(24)
        .background(Color.lizhiSurface)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.lizhiTextSecondary.opacity(0.1), lineWidth: 1))
    }
    
    private var aiInsightsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("AI Insights")
                    .font(.headline)
                    .foregroundStyle(Color.lizhiTextPrimary)
                Spacer()
                
                if isLoadingAI {
                    ProgressView().tint(Color.lizhiTextPrimary)
                } else {
                    Button {
                        // Manual specific trigger
                        Task { await fetchAI(force: true) }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .foregroundStyle(Color.lizhiTextSecondary)
                            .font(.caption)
                    }
                }
            }
            .padding(.bottom, 12)
            
            VStack(spacing: 16) {
                // Insight 1: Strategic (Visionary)
                InsightRow(
                    icon: "sparkles",
                    color: .yellow,
                    title: "Strategic Vision",
                    content: strategicIdea,
                    isLoading: isLoadingAI
                )
                
                Divider().background(Color.lizhiTextSecondary.opacity(0.2))
                
                // Insight 2: Tactical (Critical)
                InsightRow(
                    icon: "scope",
                    color: .red,
                    title: "Tactical Move",
                    content: tacticalIdea,
                    isLoading: isLoadingAI
                )
                
                Divider().background(Color.lizhiTextSecondary.opacity(0.2))
                
                HStack {
                    Spacer()
                    Text("Based on \(allTransactions.count) records")
                        .font(.caption)
                        .foregroundStyle(Color.lizhiTextSecondary)
                }
            }
            .padding(24)
            .background(Color.lizhiSurface)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.lizhiTextSecondary.opacity(0.1), lineWidth: 1))
        }
    }
    
    func refreshData(forceAI: Bool = false) {
        Task {
            // Force verify context
            try? modelContext.save()
            
            guard let engine = financialEngine else { return }
            // Pass the current view snapshot of transactions to the engine
            // This ensures data consistency with what the user sees (or is about to see)
            guard let engine = financialEngine else { return }
            
            // Debug Logs
            print("--- Refreshing Cockpit Data ---")
            print("Total Transactions: \(allTransactions.count)")
            
            // Intelligent Date Selection on First Load
            if isFirstLoad {
                 // If we have data, show the month of the MOST RECENT transaction.
                 selectedDate = allTransactions.first?.date ?? Date()
                 isFirstLoad = false
            }
            
            // Pass the intelligent date to the engine
            let metrics = await engine.calculateMetrics(from: allTransactions, for: selectedDate, granularity: selectedPeriod)
            print("Calculated Metrics (for \(selectedDate.formatted())): Income=\(metrics.activeIncome), Burn=\(metrics.totalBurn)")
            
            // Spending Habits Breakdown
            let calendar = Calendar.current
            
            // Filter Txs for Habits based on selected period and date
            let filteredTxs = allTransactions.filter {
                if selectedPeriod == .year {
                    return calendar.isDate($0.date, equalTo: selectedDate, toGranularity: .year)
                } else {
                    return calendar.isDate($0.date, equalTo: selectedDate, toGranularity: .month)
                }
            }
            
            let survival = filteredTxs.filter { $0.category == .survival && $0.type == .expense }.reduce(Decimal.zero) { $0 + CurrencyService.shared.convertToBase($1.amount, from: $1.currency) }
            let material = filteredTxs.filter { $0.category == .material && $0.type == .expense }.reduce(Decimal.zero) { $0 + CurrencyService.shared.convertToBase($1.amount, from: $1.currency) }
            let experiential = filteredTxs.filter { $0.category == .experiential && $0.type == .expense }.reduce(Decimal.zero) { $0 + CurrencyService.shared.convertToBase($1.amount, from: $1.currency) }
            let investment = filteredTxs.filter { $0.category == .investment && $0.type == .expense }.reduce(Decimal.zero) { $0 + CurrencyService.shared.convertToBase($1.amount, from: $1.currency) }
            let uncategorized = filteredTxs.filter { $0.category == .uncategorized && $0.type == .expense }.reduce(Decimal.zero) { $0 + CurrencyService.shared.convertToBase($1.amount, from: $1.currency) }
            
            // Calculate category breakdown for pie chart
            // Lookup CategoryEntity by matching subcategory to find parent category name
            var categoryTotals: [String: Double] = [:]
            for tx in filteredTxs where tx.type == .expense {
                let catName: String
                // Try to find the parent CategoryEntity that contains this subcategory
                if let parentCategory = categories.first(where: { $0.subcategories.contains(tx.subcategory) }) {
                    catName = parentCategory.name
                } else if !tx.categoryName.isEmpty {
                    catName = tx.categoryName
                } else if !tx.subcategory.isEmpty {
                    catName = tx.subcategory // Fall back to subcategory as category name
                } else {
                    catName = "Other"
                }
                let amountInBase = CurrencyService.shared.convertToBase(tx.amount, from: tx.currency)
                categoryTotals[catName, default: 0] += NSDecimalNumber(decimal: amountInBase).doubleValue
            }
            
            withAnimation(.spring) {
                // Update Title State
                self.displayMonth = formatSelectedDate() // Reuse formatter logic
                
                self.activeIncome = metrics.activeIncome
                self.totalBurn = metrics.totalBurn
                self.survivalSpend = NSDecimalNumber(decimal: survival).doubleValue
                self.materialSpend = NSDecimalNumber(decimal: material).doubleValue
                self.experientialSpend = NSDecimalNumber(decimal: experiential).doubleValue
                self.investmentSpend = NSDecimalNumber(decimal: investment).doubleValue
                self.uncategorizedSpend = NSDecimalNumber(decimal: uncategorized).doubleValue
                self.subcategoryBreakdown = categoryTotals
            }
            
            // AI Fetch Logic:
            // 1. If forced, fetch.
            // 2. If valid data exists (not placeholder) AND counts match, SKIP.
            // 3. If counts differ (new data), FETCH.
            
            let isPlaceholder = strategicIdea == "Analyzing big picture..." || strategicIdea.contains("transac")
            let hasNewData = allTransactions.count != lastAnalyzedCount
            
            if !allTransactions.isEmpty {
                if forceAI || isPlaceholder || hasNewData {
                     await fetchAI(force: forceAI)
                }
            }
        }
    }
    
    func fetchAI(force: Bool = false) async {
        guard !isLoadingAI, !allTransactions.isEmpty else { return }
        
        // Double check redundant call if not forced
        if !force && allTransactions.count == lastAnalyzedCount && !(strategicIdea == "Analyzing big picture...") {
            return
        }
        
        isLoadingAI = true
        do {
            // Using first 100 for context window efficiency
            let forecast = try await AIService.shared.generateForecast(transactions: Array(allTransactions.prefix(100)), assets: assets)
            
            withAnimation {
                self.strategicInsight(forecast)
                // Save the count we analyzed
                self.lastAnalyzedCount = allTransactions.count
                isLoadingAI = false
            }
        } catch {
             print("AI Error: \(error)")
             withAnimation {
                 self.strategicIdea = "Oracle disconnected."
                 self.tacticalIdea = "Try again later."
                 isLoadingAI = false
             }
        }
    }
    
    func strategicInsight(_ forecast: FinancialForecast) {
        self.strategicIdea = forecast.primaryInsight
        self.tacticalIdea = forecast.secondaryInsight
    }
    
    // Date Helpers
    func moveDate(by value: Int) {
        let calendar = Calendar.current
        if let newDate = calendar.date(byAdding: selectedPeriod == .year ? .year : .month, value: value, to: selectedDate) {
            selectedDate = newDate
            refreshData()
            triggerHaptic(.glassTap)
        }
    }
    
    func formatSelectedDate() -> String {
        if selectedPeriod == .year {
            return selectedDate.formatted(.dateTime.year())
        } else {
            return selectedDate.formatted(.dateTime.month(.abbreviated).year())
        }
    }
}

// Components

struct MetricCard: View {
    let title: String
    let value: Double
    let type: MetricType
    
    enum MetricType {
        case burn
        case income
    }
    
    @Environment(\.colorScheme) var colorScheme
    
    var gradientColors: [Color] {
        switch type {
        case .burn:
            return colorScheme == .dark 
                ? [Color(hex: "5A2D2D"), Color(hex: "2A1515")] 
                : [Color(hex: "FFEBEE"), Color(hex: "FFCDD2")] // Soft Red in Light Mode
        case .income:
            return colorScheme == .dark 
                ? [Color(hex: "1F4E4E"), Color(hex: "0F2626")] 
                : [Color(hex: "E0F2F1"), Color(hex: "B2DFDB")] // Soft Teal in Light Mode
        }
    }
    
    var textColor: Color {
        // High contrast for text. White for Dark Mode cards, Dark for Light Mode Pastel cards.
        return colorScheme == .dark ? .white : .black
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundStyle(textColor.opacity(0.8))
            
            Spacer()
            
            Text("$\(Int(value).formattedWithSeparator)")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(textColor)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .overlay(RoundedRectangle(cornerRadius: 28).stroke(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05), lineWidth: 1))
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
                .foregroundStyle(Color.lizhiTextSecondary)
        }
    }
}

struct InsightRow: View {
    let icon: String
    let color: Color
    let title: String
    let content: String
    let isLoading: Bool
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.title2)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(color.opacity(0.8))
                    .textCase(.uppercase)
                
                Text(content)
                    .font(.subheadline)
                    .foregroundStyle(Color.lizhiTextPrimary.opacity(0.95))
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .redacted(reason: isLoading ? .placeholder : [])
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    CockpitView()
        .preferredColorScheme(.dark)
}
