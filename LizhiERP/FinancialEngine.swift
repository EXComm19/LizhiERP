import Foundation
import SwiftData

actor FinancialEngine {
    private var modelContainer: ModelContainer
    
    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }
    
    func processSubscriptions() {
        let today = Date()
        let descriptor = FetchDescriptor<Subscription>(predicate: #Predicate { $0.isActive })
        
        do {
            // Must use modelContext of actor which creates fresh context
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
            try? modelContext.save()
        } catch {
            print("Subscription processing error: \(error)")
        }
    }
    
    /// Helper to get a fresh context on the actor's thread
    private var modelContext: ModelContext {
        ModelContext(modelContainer)
    }
    
    /// Calculates the Lizhi Index for a specific month.
    /// Formula: Active Income / (Survival + Material + Experiential Expenses)
    func calculateLizhiIndex(for date: Date = Date()) -> Double {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: date)
        guard let startOfMonth = calendar.date(from: components),
              let endOfMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth) else {
            return 0.0
        }
        
        // Fix: Use raw value or fetch all and filter in memory if predicate fails on Enums.
        // For robustness in this specific SwiftData version context, we'll fetch by date and filter in memory.
        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate { $0.date >= startOfMonth && $0.date < endOfMonth }
        )
        
        do {
            let transactions = try modelContext.fetch(descriptor)
            
            var activeIncome: Decimal = 0
            var expenses: Decimal = 0
            
            for tx in transactions {
                // Multi-Currency Conversion
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
            print("Error fetching transactions: \(error)")
            return 0.0
        }
    }
    
    /// Calculates FIRE Progress.
    /// Formula: Total Projected Passive Income / TTM Expenses
    func calculateFIREProgress() -> Double {
        // 1. Calculate Projected Passive Income (4% Rule on Assets)
        var totalAssets: Decimal = 0
        let assetDescriptor = FetchDescriptor<AssetEntity>()
        
        do {
            let assets = try modelContext.fetch(assetDescriptor)
            // Fix: Use totalValue (Holdings * Price) and convert currency
            totalAssets = assets.reduce(0) { sum, asset in
                let valueInBase = CurrencyService.shared.convertToBase(asset.totalValue, from: asset.currency)
                return sum + valueInBase
            }
        } catch {
            print("Error fetching assets: \(error)")
        }
        
        let projectedPassiveIncome = totalAssets * 0.04
        
        // 2. Calculate TTM Expenses (Trailing Twelve Months)
        let calendar = Calendar.current
        guard let oneYearAgo = calendar.date(byAdding: .year, value: -1, to: Date()) else {
            return 0.0
        }
        
        // Attempting to avoid Enum capture crash by fetching date range only
        let txDescriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate { $0.date >= oneYearAgo } 
        )
        
        var ttmExpenses: Decimal = 0
        do {
            let transactions = try modelContext.fetch(txDescriptor)
            for tx in transactions {
                // Filter in memory for safety
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
    
    /// Returns tuple of (Active Income, Total Expenses) for the specified period (month or year)
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
        
        // Filter in memory from the passed snapshot (Source of Truth from View)
        for tx in transactions {
            if tx.date >= startOfPeriod && tx.date < endOfPeriod {
                let amountInBase = CurrencyService.shared.convertToBase(tx.amount, from: tx.currency)
                
                if tx.isActiveIncome {
                    activeIncome += amountInBase
                } else if tx.type == .expense {
                    // Exclude investments from "Burn"
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
    
    /// Recalculates balances for all assets with a Custom ID (Bank Accounts).
    /// Formula: Current Balance = Initial Balance + Total Income (Linked) - Total Expenses (Linked)
    func recalculateAssetBalances() async {
        let assetDescriptor = FetchDescriptor<AssetEntity>(predicate: #Predicate { $0.customID != nil })
        let txDescriptor = FetchDescriptor<Transaction>(predicate: #Predicate { $0.linkedAccountID != nil })
        
        do {
            let assets = try modelContext.fetch(assetDescriptor)
            let transactions = try modelContext.fetch(txDescriptor)
            
            // Group transactions by Account ID for efficiency
            let txsByAccount = Dictionary(grouping: transactions, by: { $0.linkedAccountID ?? "" })
            
            for asset in assets {
                guard let accountID = asset.customID else { continue }
                
                var newBalance = asset.initialBalance
                print("DEBUG: Engine - Recalculating Asset: \(asset.ticker) (ID: \(accountID)). Initial Balance: \(newBalance)")
                
                if let accountTxs = txsByAccount[accountID] {
                    print("DEBUG: Engine - Found \(accountTxs.count) linked transactions for \(accountID)")
                    for tx in accountTxs {
                        // Multi-currency handling: 
                        // For MVP, assume same currency or raw amount impact as per request.
                        let amountEffect = tx.amount
                        
                        if tx.type == .income {
                            newBalance += amountEffect
                            print("DEBUG:   + Income: \(amountEffect)")
                        } else if tx.type == .expense {
                            newBalance -= amountEffect
                            print("DEBUG:   - Expense: \(amountEffect)")
                        }
                    }
                } else {
                    print("DEBUG: Engine - No linked transactions found for \(accountID)")
                }
                
                
                // Polymorphic Assignment:
                if asset.type == .cash {
                    asset.cashBalance = newBalance
                    // asset.marketValue is ignored or kept as 0 for cash
                    print("DEBUG: Engine - Final Cash Balance for \(asset.ticker): \(newBalance)")
                } else {
                    asset.marketValue = newBalance
                    print("DEBUG: Engine - Final Market Value for \(asset.ticker): \(newBalance)")
                }
                
                asset.lastUpdated = Date()
            }
            
            try modelContext.save()
            print("FinancialEngine: Asset balances recalculated.")
            
        } catch {
            print("Error recalculating asset balances: \(error)")
        }
    }
}
