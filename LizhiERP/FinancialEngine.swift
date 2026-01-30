import Foundation
import SwiftData

actor FinancialEngine {
    private var modelContainer: ModelContainer
    private var _modelContext: ModelContext // Stored property
    
    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        // Create the context once and hold it
        self._modelContext = ModelContext(modelContainer)
        self._modelContext.autosaveEnabled = false // We will control saving manually
    }
    
    // Accessor
    private var modelContext: ModelContext {
        return _modelContext
    }
    
    // MARK: - Subscriptions
    func processSubscriptions() {
        let today = Date()
        let descriptor = FetchDescriptor<Subscription>(predicate: #Predicate { $0.isActive })
        
        do {
            let subs = try modelContext.fetch(descriptor)
            
            for sub in subs {
                var safetyCounter = 0
                while sub.firstBillDate <= today && safetyCounter < 12 {
                    let tx = Transaction(
                        amount: sub.amount,
                        type: .expense,
                        category: .survival,
                        source: .spending,
                        date: sub.firstBillDate,
                        contextTags: ["Subscription", sub.name],
                        subcategory: "Bills"
                    )
                    modelContext.insert(tx)
                    sub.advanceDueDate()
                    safetyCounter += 1
                }
            }
            if modelContext.hasChanges {
                try modelContext.save()
            }
        } catch {
            print("Subscription processing error: \(error)")
        }
    }
    
    // MARK: - Metrics
    
    /// Calculates the Lizhi Index for a specific month.
    func calculateLizhiIndex(for date: Date = Date()) -> Double {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: date)
        guard let startOfMonth = calendar.date(from: components),
              let endOfMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth) else {
            return 0.0
        }
        
        // Fetch all needed data
        // Note: Using a fresh descriptor to ensure we don't get cached stale data if query generation changes
        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate { $0.date >= startOfMonth && $0.date < endOfMonth }
        )
        
        do {
            let transactions = try modelContext.fetch(descriptor)
            
            var activeIncome: Decimal = 0
            var expenses: Decimal = 0
            
            for tx in transactions {
                let convertedAmount = CurrencyService.shared.convertToBase(tx.amount, from: tx.currency)
                
                if tx.isActiveIncome {
                    activeIncome += convertedAmount
                } else if tx.type == .expense {
                    if tx.category != .investment {
                        expenses += convertedAmount
                    }
                }
            }
            
            guard expenses > 0 else { return activeIncome > 0 ? 100.0 : 0.0 }
            return NSDecimalNumber(decimal: activeIncome / expenses).doubleValue
            
        } catch {
            print("Error calculating Lizhi Index: \(error)")
            return 0.0
        }
    }
    
    /// Calculates FIRE Progress.
    func calculateFIREProgress() -> Double {
        // 1. Calculate Projected Passive Income (4% Rule on Assets)
        var totalAssets: Decimal = 0
        let assetDescriptor = FetchDescriptor<AssetEntity>()
        
        do {
            let assets = try modelContext.fetch(assetDescriptor)
            totalAssets = assets.reduce(0) { sum, asset in
                let valueInBase = CurrencyService.shared.convertToBase(asset.totalValue, from: asset.currency)
                return sum + valueInBase
            }
        } catch {
            print("Error fetching assets: \(error)")
        }
        
        let projectedPassiveIncome = totalAssets * 0.04
        
        // 2. Calculate TTM Expenses
        let calendar = Calendar.current
        guard let oneYearAgo = calendar.date(byAdding: .year, value: -1, to: Date()) else {
            return 0.0
        }
        
        let txDescriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate { $0.date >= oneYearAgo } 
        )
        
        var ttmExpenses: Decimal = 0
        do {
            let transactions = try modelContext.fetch(txDescriptor)
            for tx in transactions {
                if tx.type == .expense && tx.category != .investment {
                    let amountInBase = CurrencyService.shared.convertToBase(tx.amount, from: tx.currency)
                    ttmExpenses += amountInBase
                }
            }
        } catch {
            print("Error fetching TTM transactions: \(error)")
        }
        
        guard ttmExpenses > 0 else { return totalAssets > 0 ? 100.0 : 0.0 }
        
        return NSDecimalNumber(decimal: projectedPassiveIncome / ttmExpenses).doubleValue
    }
    
    /// Returns tuple of (Active Income, Total Expenses) for the specified period
    func calculateMetrics(from transactions: [Transaction], for date: Date = Date(), granularity: Calendar.Component = .month) -> (activeIncome: Double, totalBurn: Double) {
        let calendar = Calendar.current
        
        let startOfPeriod: Date
        let endOfPeriod: Date
        
        if granularity == .year {
            let components = calendar.dateComponents([.year], from: date)
            startOfPeriod = calendar.date(from: components)!
            endOfPeriod = calendar.date(byAdding: .year, value: 1, to: startOfPeriod)!
        } else {
            let components = calendar.dateComponents([.year, .month], from: date)
            startOfPeriod = calendar.date(from: components)!
            endOfPeriod = calendar.date(byAdding: .month, value: 1, to: startOfPeriod)!
        }
        
        var activeIncome: Decimal = 0
        var expenses: Decimal = 0
        
        for tx in transactions {
            if tx.date >= startOfPeriod && tx.date < endOfPeriod {
                let amountInBase = CurrencyService.shared.convertToBase(tx.amount, from: tx.currency)
                
                if tx.isActiveIncome {
                    activeIncome += amountInBase
                } else if tx.type == .expense {
                    if tx.category != .investment {
                        expenses += amountInBase
                    }
                }
            }
        }
        
        return (
            NSDecimalNumber(decimal: activeIncome).doubleValue,
            NSDecimalNumber(decimal: expenses).doubleValue
        )
    }
    
    // MARK: - Asset Management
    
    /// Recalculates balances for all assets.
    /// Handles: Income, Expenses, Transfers (Bank-to-Bank), and Investments (Bank-to-Asset).
    func recalculateAssetBalances() async {
        // Fetch fresh copies of everything using our stored context
        let assetDescriptor = FetchDescriptor<AssetEntity>()
        let txDescriptor = FetchDescriptor<Transaction>()
        
        do {
            let assets = try modelContext.fetch(assetDescriptor)
            let transactions = try modelContext.fetch(txDescriptor)
            
            // 1. Reset all assets to initial state
            for asset in assets {
                if asset.type == .cash {
                    asset.cashBalance = asset.initialBalance
                } else {
                    // For stocks, reset to initial holdings
                    asset.holdings = asset.initialHoldings ?? 0
                    // Market Value remains implicitly "current price" so we don't reset it here usually,
                    // but 'totalValue' is derived. 'marketValue' is the UNIT PRICE.
                }
            }
            
            // 2. Replay History
            for tx in transactions {
                // In MVP, assuming same currency or simple raw amount impact.
                // Future: Use CurrencyService to convert amount to asset's currency.
                let amount = tx.amount
                
                // --- A. HANDLE SOURCE (Money Out) ---
                if let sourceID = tx.linkedAccountID,
                   let sourceAsset = assets.first(where: { $0.customID == sourceID }) {
                    
                    if sourceAsset.type == .cash {
                        // Deduct from Source (Expense, Transfer Out, Asset Purchase)
                        // Note: Income adds to source, others subtract.
                        if tx.type == .income {
                            sourceAsset.cashBalance = (sourceAsset.cashBalance ?? 0) + amount
                        } else {
                            // Expense, Transfer, Asset Purchase all reduce the source balance
                            sourceAsset.cashBalance = (sourceAsset.cashBalance ?? 0) - amount
                        }
                    }
                }
                
                // --- B. HANDLE DESTINATION (Money In) ---
                
                // Case 1: Cash Transfer (Bank -> Bank)
                if tx.type == .transfer,
                   let destID = tx.destinationAccountID,
                   let destAsset = assets.first(where: { $0.customID == destID }) {
                    
                    if destAsset.type == .cash {
                        destAsset.cashBalance = (destAsset.cashBalance ?? 0) + amount
                    }
                }
                
                // Case 2: Asset Purchase (Bank -> Stock)
                if tx.type == .assetPurchase,
                   let targetUUID = tx.targetAssetID,
                   let targetAsset = assets.first(where: { $0.id == targetUUID }) {
                    
                    // Increase Holdings (Shares)
                    if let units = tx.units {
                        targetAsset.holdings += units
                    }
                }
            }
            
            // 3. Mark Valid & Save
            for asset in assets {
                 asset.lastUpdated = Date()
            }
            
            if modelContext.hasChanges {
                try modelContext.save()
                print("FinancialEngine: Asset balances reconciled.")
            }
            
        } catch {
            print("Error recalculating asset balances: \(error)")
        }
    }
    
    // MARK: - Stock Transactions
    
    /// Record a stock purchase transaction
    func recordStockPurchase(
        assetID: UUID,
        units: Decimal,
        pricePerUnit: Decimal,
        fees: Decimal,
        date: Date,
        notes: String = ""
    ) async {
        let transaction = StockTransaction(
            assetID: assetID,
            type: .buy,
            units: units,
            pricePerUnit: pricePerUnit,
            fees: fees,
            date: date,
            notes: notes
        )
        
        modelContext.insert(transaction)
        
        // Update asset holdings
        let targetID = assetID
        if let asset = try? modelContext.fetch(FetchDescriptor<AssetEntity>(predicate: #Predicate { $0.id == targetID })).first {
            asset.holdings += units
            asset.lastUpdated = date
        }
        
        do {
            try modelContext.save()
            print("✅ Stock purchase recorded: \(units) units @ $\(pricePerUnit)")
        } catch {
            print("❌ Failed to save stock purchase: \(error)")
        }
    }
    
    /// Record a stock sale transaction
    func recordStockSale(
        assetID: UUID,
        units: Decimal,
        pricePerUnit: Decimal,
        fees: Decimal,
        date: Date,
        notes: String = ""
    ) async {
        let transaction = StockTransaction(
            assetID: assetID,
            type: .sell,
            units: units,
            pricePerUnit: pricePerUnit,
            fees: fees,
            date: date,
            notes: notes
        )
        
        modelContext.insert(transaction)
        
        // Update asset holdings
        let targetID = assetID
        if let asset = try? modelContext.fetch(FetchDescriptor<AssetEntity>(predicate: #Predicate { $0.id == targetID })).first {
            asset.holdings -= units
            asset.lastUpdated = date
        }
        
        do {
            try modelContext.save()
            print("✅ Stock sale recorded: \(units) units @ $\(pricePerUnit)")
        } catch {
            print("❌ Failed to save stock sale: \(error)")
        }
    }
    
    /// Get all stock transactions for a specific asset
    func getStockTransactions(assetID: UUID) -> [StockTransaction] {
        let targetID = assetID
        let descriptor = FetchDescriptor<StockTransaction>(
            predicate: #Predicate { $0.assetID == targetID },
            sortBy: [SortDescriptor(\.date, order: .forward)] // Oldest first for correct cost basis
        )
        
        do {
            return try modelContext.fetch(descriptor)
        } catch {
            print("❌ Failed to fetch stock transactions: \(error)")
            return []
        }
    }
    
    /// Calculate average cost basis for a stock using weighted average method
    func calculateAverageCostBasis(assetID: UUID) -> Decimal {
        let transactions = getStockTransactions(assetID: assetID)
        
        var totalCost: Decimal = 0
        var totalUnits: Decimal = 0
        
        for tx in transactions {
            if tx.type == .buy {
                totalCost += tx.totalAmount
                totalUnits += tx.units
            } else { // sell
                // For sells, reduce the total invested proportionally
                let ratio = tx.units / totalUnits
                totalCost -= (totalCost * ratio)
                totalUnits -= tx.units
            }
        }
        
        guard totalUnits > 0 else { return 0 }
        return totalCost / totalUnits
    }
    
    /// Calculate total amount invested (all buys minus sells)
    func calculateTotalInvested(assetID: UUID) -> Decimal {
        let transactions = getStockTransactions(assetID: assetID)
        
        var totalInvested: Decimal = 0
        
        for tx in transactions {
            if tx.type == .buy {
                totalInvested += tx.totalAmount
            } else {
                totalInvested -= tx.totalAmount
            }
        }
        
        return totalInvested
    }
    
    /// Delete a stock transaction
    func deleteStockTransaction(_ transaction: StockTransaction) async {
        // Reverse the holdings change
        let targetID = transaction.assetID
        if let asset = try? modelContext.fetch(FetchDescriptor<AssetEntity>(predicate: #Predicate { $0.id == targetID })).first {
            if transaction.type == .buy {
                asset.holdings -= transaction.units
            } else {
                asset.holdings += transaction.units
            }
        }
        
        modelContext.delete(transaction)
        
        do {
            try modelContext.save()
        } catch {
            print("❌ Failed to delete stock transaction: \(error)")
        }
    }
}
