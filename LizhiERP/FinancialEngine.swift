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
    
    /// Recalculates balances for all assets with a Custom ID.
    func recalculateAssetBalances() async {
        // Fetch fresh copies of everything using our stored context
        let assetDescriptor = FetchDescriptor<AssetEntity>(predicate: #Predicate { $0.customID != nil })
        let txDescriptor = FetchDescriptor<Transaction>(predicate: #Predicate { $0.linkedAccountID != nil })
        
        do {
            let assets = try modelContext.fetch(assetDescriptor)
            let transactions = try modelContext.fetch(txDescriptor)
            
            // Group transactions by Account ID for efficiency
            let txsByAccount = Dictionary(grouping: transactions, by: { $0.linkedAccountID ?? "" })
            
            var updatesCount = 0
            
            for asset in assets {
                guard let accountID = asset.customID else { continue }
                
                var newBalance = asset.initialBalance
                
                if let accountTxs = txsByAccount[accountID] {
                    for tx in accountTxs {
                        // In MVP, assuming same currency.
                        // Future: Convert tx.amount to asset.currency
                        let amountEffect = tx.amount
                        
                        if tx.type == .income {
                            newBalance += amountEffect
                        } else if tx.type == .expense {
                            newBalance -= amountEffect
                        } else if tx.type == .assetPurchase {
                            newBalance -= amountEffect
                        }
                    }
                }
                
                print("DEBUG: Engine - Updating \(asset.ticker) (\(accountID)) to \(newBalance)")
                
                // Polymorphic Assignment
                if asset.type == .cash {
                    asset.cashBalance = newBalance
                } else {
                    asset.marketValue = newBalance
                }
                
                asset.lastUpdated = Date()
                updatesCount += 1
            }
            
            if updatesCount > 0 && modelContext.hasChanges {
                try modelContext.save()
                print("DEBUG: Engine - Successfully saved \(updatesCount) asset updates to disk.")
            } else {
                print("DEBUG: Engine - No changes needed.")
            }
            
        } catch {
            print("Error recalculating asset balances: \(error)")
        }
    }
}
