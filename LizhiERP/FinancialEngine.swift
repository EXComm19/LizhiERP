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
                if tx.isActiveIncome {
                    activeIncome += tx.amount
                } else if tx.type == .expense {
                    if tx.category != .investment {
                        expenses += tx.amount
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
            totalAssets = assets.reduce(0) { $0 + $1.marketValue }
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
                    ttmExpenses += tx.amount
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
                if tx.isActiveIncome {
                    activeIncome += tx.amount
                } else if tx.type == .expense {
                    // Exclude investments from "Burn"
                    if tx.category != .investment {
                        expenses += tx.amount
                    }
                }
            }
        }
        
        return (
            NSDecimalNumber(decimal: activeIncome).doubleValue,
            NSDecimalNumber(decimal: expenses).doubleValue
        )
    }
}
