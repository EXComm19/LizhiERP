import SwiftData
import SwiftUI

@MainActor
class DataManager {
    static let shared = DataManager()
    
    func seedCategories(context: ModelContext) {
        // Check if categories exist
        let descriptor = FetchDescriptor<CategoryEntity>()
        let existing = (try? context.fetch(descriptor)) ?? []
        
        if !existing.isEmpty { return } // Already seeded
        
        // Seed Expense Defaults
        let expenseDefaults: [CategoryEntity] = [
            CategoryEntity(name: "Food", icon: "fork.knife", type: .expense, mappedCategory: .survival, subcategories: ["Groceries", "Dining Out", "Snacks", "Coffee", "Delivery"], sortOrder: 0),
            CategoryEntity(name: "Installments", icon: "arrow.triangle.2.circlepath", type: .expense, mappedCategory: .survival, subcategories: ["Zip", "Afterpay", "PayPal", "Loan", "Klarna"], sortOrder: 1),
            CategoryEntity(name: "Transport", icon: "car.fill", type: .expense, mappedCategory: .survival, subcategories: ["Fuel", "Uber/Taxi", "Public Transport", "Parking", "Maintenance"], sortOrder: 2),
            CategoryEntity(name: "Shopping", icon: "bag.fill", type: .expense, mappedCategory: .material, subcategories: ["Clothing", "Electronics", "Home", "Gifts", "Beauty"], sortOrder: 3),
            CategoryEntity(name: "Study", icon: "book.fill", type: .expense, mappedCategory: .investment, subcategories: ["Course", "Books", "Software", "Tuition"], sortOrder: 4),
            CategoryEntity(name: "Travel", icon: "airplane", type: .expense, mappedCategory: .experiential, subcategories: ["Flights", "Hotel", "Activity", "Visa"], sortOrder: 5),
            CategoryEntity(name: "Bills", icon: "doc.text.fill", type: .expense, mappedCategory: .survival, subcategories: ["Phone", "Internet", "Electricity", "Water", "Council"], sortOrder: 6),
            CategoryEntity(name: "Entmt", icon: "gamecontroller.fill", type: .expense, mappedCategory: .experiential, subcategories: ["Games", "Movies", "Events", "Streaming"], sortOrder: 7),
            CategoryEntity(name: "Health", icon: "heart.fill", type: .expense, mappedCategory: .survival, subcategories: ["Doctor", "Pharmacy", "Gym", "Insurance"], sortOrder: 8)
        ]
        
        // Seed Income Defaults
        let incomeDefaults: [CategoryEntity] = [
            CategoryEntity(name: "Paycheck", icon: "dollarsign.circle.fill", type: .income, mappedCategory: .survival, subcategories: ["Main Job", "Bonus", "Overtime"], sortOrder: 0),
            CategoryEntity(name: "Hustle", icon: "bolt.fill", type: .income, mappedCategory: .investment, subcategories: ["Freelance", "Consulting", "Side Project", "Sales"], sortOrder: 1),
            CategoryEntity(name: "Investment", icon: "chart.line.uptrend.xyaxis", type: .income, mappedCategory: .investment, subcategories: ["Dividends", "Interest", "Real Estate", "Crypto"], sortOrder: 2),
            CategoryEntity(name: "Gift", icon: "gift.fill", type: .income, mappedCategory: .uncategorized, subcategories: ["Birthday", "Red Packet", "Other"], sortOrder: 3)
        ]
        
        for cat in expenseDefaults + incomeDefaults {
            context.insert(cat)
        }
        
        // Save
        try? context.save()
        print("DataManager: Categories seeded.")
    }
    func resetCategories(context: ModelContext) {
        do {
             // Delete all existing
             try context.delete(model: CategoryEntity.self)
             // Re-seed
             seedCategories(context: context)
             print("DataManager: Categories reset to defaults.")
        } catch {
             print("DataManager: Failed to reset categories: \(error)")
        }
    }
}
