import SwiftUI
import SwiftData

struct StockDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    let asset: AssetEntity
    
    
    @State private var transactions: [StockTransaction] = []
    @State private var averageCost: Decimal = 0
    @State private var totalInvested: Decimal = 0
    @State private var unrealizedGainLoss: Decimal = 0
    @State private var gainLossPercent: Double = 0
    @State private var isRefreshingPrice: Bool = false
    @State private var priceService = StockPriceService()
    
    private var engine: FinancialEngine {
        FinancialEngine(modelContainer: modelContext.container)
    }

    
    var body: some View {
        ZStack {
            Color.lizhiBackground.ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 0) {
                // Header
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
                    
                    VStack(spacing: 2) {
                        Text(asset.ticker.uppercased())
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.lizhiTextPrimary)
                        
                        Text(asset.id.uuidString)
                            .font(.system(size: 8, design: .monospaced))
                            .foregroundStyle(Color.lizhiTextSecondary.opacity(0.4))
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .frame(maxWidth: 120)
                            .onTapGesture {
                                UIPasteboard.general.string = asset.id.uuidString
                                triggerHaptic(.glassTap)
                            }
                    }
                    
                    Spacer()
                    
                    Button {
                        refreshPrice()
                    } label: {
                        Image(systemName: isRefreshingPrice ? "arrow.triangle.2.circlepath" : "arrow.clockwise")
                            .font(.title3)
                            .foregroundStyle(Color.lizhiTextPrimary)
                            .rotationEffect(.degrees(isRefreshingPrice ? 360 : 0))
                            .animation(isRefreshingPrice ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isRefreshingPrice)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 16)
                
                // Summary Card
                VStack(alignment: .leading, spacing: 16) {
                    // Current Holdings & Price
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("CURRENT HOLDINGS")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundStyle(Color.lizhiTextSecondary)
                            Text("\(asset.holdings.formatted()) units")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundStyle(Color.lizhiTextPrimary)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("CURRENT PRICE")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundStyle(Color.lizhiTextSecondary)
                            Text("$\(NSDecimalNumber(decimal: asset.marketValue).doubleValue.formatted(.number.precision(.fractionLength(2))))")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundStyle(Color.lizhiTextPrimary)
                        }
                    }
                    
                    Divider().background(Color.lizhiTextSecondary.opacity(0.3))
                    
                    // Market Value
                    HStack {
                        Text("Market Value")
                            .font(.subheadline)
                            .foregroundStyle(Color.lizhiTextSecondary)
                        Spacer()
                        Text("$\(NSDecimalNumber(decimal: asset.totalValue).doubleValue.formatted(.number.precision(.fractionLength(2))))")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.lizhiTextPrimary)
                    }
                    
                    // Average Cost
                    HStack {
                        Text("Average Cost")
                            .font(.subheadline)
                            .foregroundStyle(Color.lizhiTextSecondary)
                        Spacer()
                        Text("$\(NSDecimalNumber(decimal: averageCost).doubleValue.formatted(.number.precision(.fractionLength(2))))")
                            .font(.headline)
                            .foregroundStyle(Color.lizhiTextPrimary)
                    }
                    
                    // Total Invested
                    HStack {
                        Text("Total Invested")
                            .font(.subheadline)
                            .foregroundStyle(Color.lizhiTextSecondary)
                        Spacer()
                        Text("$\(NSDecimalNumber(decimal: totalInvested).doubleValue.formatted(.number.precision(.fractionLength(2))))")
                            .font(.headline)
                            .foregroundStyle(Color.lizhiTextPrimary)
                    }
                    
                    Divider().background(Color.lizhiTextSecondary.opacity(0.3))
                    
                    // Unrealized P&L
                    VStack(spacing: 8) {
                        HStack {
                            Text("Unrealized Gain/Loss")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(Color.lizhiTextSecondary)
                            Spacer()
                        }
                        
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            Text("$\(NSDecimalNumber(decimal: unrealizedGainLoss).doubleValue.formatted(.number.precision(.fractionLength(2))))")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundStyle(unrealizedGainLoss >= 0 ? Color.green : Color.red)
                            
                            HStack(spacing: 4) {
                                Image(systemName: gainLossPercent >= 0 ? "arrow.up.right" : "arrow.down.right")
                                Text("\(abs(gainLossPercent).formatted(.number.precision(.fractionLength(2))))%")
                            }
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundStyle(gainLossPercent >= 0 ? Color.green : Color.red)
                            
                            Spacer()
                        }
                    }
                }
                .padding(20)
                .background(Color.lizhiSurface)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.lizhiTextSecondary.opacity(0.1), lineWidth: 1))
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
                
                // Transaction History Header
                Text("TRANSACTION HISTORY")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.lizhiTextSecondary)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
                
                // Transaction List
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(transactions) { tx in
                            StockTransactionRow(transaction: tx)
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                let tx = transactions[index]
                                Task {
                                    await engine.deleteStockTransaction(tx)
                                    await refreshData()
                                }
                            }
                        }
                        
                        if transactions.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "chart.line.downtrend.xyaxis")
                                    .font(.system(size: 60))
                                    .foregroundStyle(Color.lizhiTextSecondary.opacity(0.5))
                                
                                Text("No transactions yet")
                                    .font(.headline)
                                    .foregroundStyle(Color.lizhiTextSecondary)
                                
                                Text("Buy or sell stock to see history here")
                                    .font(.subheadline)
                                    .foregroundStyle(Color.lizhiTextSecondary.opacity(0.7))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                        }
                        
                        Spacer().frame(height: 100)
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
        .onAppear {
            Task {
                await refreshData()
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
    
    func refreshData() async {
        // Query directly from view's context for immediate data visibility
        let targetID = asset.id
        let descriptor = FetchDescriptor<StockTransaction>(
            predicate: #Predicate { $0.assetID == targetID },
            sortBy: [SortDescriptor(\.date, order: .reverse)] // Newest first for display
        )
        
        do {
            let fetchedTransactions = try modelContext.fetch(descriptor)
            
            // Calculate cost basis (oldest first)
            var totalCost: Decimal = 0
            var totalUnits: Decimal = 0
            
            // Process in chronological order for correct calculation
            for tx in fetchedTransactions.reversed() {
                if tx.type == .buy {
                    totalCost += tx.totalAmount
                    totalUnits += tx.units
                } else { // sell
                    if totalUnits > 0 {
                        let ratio = tx.units / totalUnits
                        totalCost -= (totalCost * ratio)
                        totalUnits -= tx.units
                    }
                }
            }
            
            let avgCost = totalUnits > 0 ? totalCost / totalUnits : 0
            
            // Calculate total invested (sum of all purchases minus sales)
            var totalInv: Decimal = 0
            for tx in fetchedTransactions {
                if tx.type == .buy {
                    totalInv += tx.totalAmount
                } else {
                    totalInv -= tx.totalAmount
                }
            }
            
            await MainActor.run {
                transactions = fetchedTransactions
                averageCost = avgCost
                totalInvested = totalInv
                unrealizedGainLoss = asset.totalValue - totalInvested
                
                if totalInvested > 0 {
                    gainLossPercent = (Double(truncating: unrealizedGainLoss as NSNumber) / Double(truncating: totalInvested as NSNumber)) * 100
                } else {
                    gainLossPercent = 0
                }
            }
        } catch {
            print("❌ Failed to fetch stock transactions: \(error)")
        }
    }
    
    func refreshPrice() {
        isRefreshingPrice = true
        triggerHaptic(.glassTap)
        
        Task {
            do {
                try await priceService.updateAssetPrice(asset: asset, context: modelContext)
                await refreshData()
                await MainActor.run {
                    isRefreshingPrice = false
                }
            } catch {
                print("Failed to refresh price: \(error)")
                await MainActor.run {
                    isRefreshingPrice = false
                }
            }
        }
    }
}

struct StockTransactionRow: View {
    let transaction: StockTransaction
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            Circle()
                .fill(transaction.type == .buy ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
                .frame(width: 48, height: 48)
                .overlay(
                    Image(systemName: transaction.type == .buy ? "plus.circle.fill" : "minus.circle.fill")
                        .foregroundStyle(transaction.type == .buy ? Color.green : Color.red)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(transaction.type.rawValue.uppercased())
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.lizhiTextPrimary)
                    
                    Text(transaction.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(Color.lizhiTextSecondary)
                }
                
                Text("\(transaction.type == .buy ? "+" : "-")\(transaction.units.formatted()) @ $\(NSDecimalNumber(decimal: transaction.pricePerUnit).doubleValue.formatted(.number.precision(.fractionLength(2))))")
                    .font(.subheadline)
                    .foregroundStyle(Color.lizhiTextSecondary)
                
                if transaction.fees > 0 {
                    Text("Fee: $\(NSDecimalNumber(decimal: transaction.fees).doubleValue.formatted(.number.precision(.fractionLength(2))))")
                        .font(.caption)
                        .foregroundStyle(Color.lizhiTextSecondary.opacity(0.7))
                }
            }
            
            Spacer()
            
            Text("$\(NSDecimalNumber(decimal: transaction.totalAmount).doubleValue.formatted(.number.precision(.fractionLength(2))))")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundStyle(transaction.type == .buy ? Color.green : Color.red)
        }
        .padding()
        .background(Color.lizhiSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.lizhiTextSecondary.opacity(0.1), lineWidth: 1))
    }
}
