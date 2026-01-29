import SwiftData
import SwiftUI

@MainActor
class DataManager {
    static let shared = DataManager()
    
    func seedCategories(context: ModelContext) {
        // Combined Target Structure (User Request + Original Defaults)
        let targets: [(name: String, icon: String, type: TransactionType, map: TransactionCategory, subs: [String])] = [
            // Expenses (Merged)
            ("Travel", "airplane", .expense, .experiential, ["General", "Flights", "Hotel", "Activity", "Visa"]),
            ("Entertainment", "gamecontroller.fill", .expense, .experiential, ["Music", "Activity", "Streaming", "Games", "Movies", "Events"]),
            ("Food", "fork.knife", .expense, .survival, ["Groceries", "Delivery", "Solo Meal", "Drink", "Dessert", "Snacks", "Dining Out"]),
            ("Bills", "doc.text.fill", .expense, .survival, ["Subscription", "Phone", "Internet", "Electricity", "Water", "Council"]),
            ("Shopping", "bag.fill", .expense, .material, ["Electronics", "Home", "Clothing", "Gifts", "Beauty"]),
            ("Transport", "car.fill", .expense, .survival, ["Public Transport", "Fuel", "Parking", "Ride", "Maintenance"]),
            ("Health", "heart.fill", .expense, .survival, ["Pharmacy", "Gym", "Consult", "Optical", "Personal Care", "Equipment", "Insurance"]),
            ("Study", "book.fill", .expense, .investment, ["Software", "Space", "Consumables", "Course", "Books", "Tuition"]),
            
            // Income (Original Defaults)
            ("Paycheck", "dollarsign.circle.fill", .income, .survival, ["Main Job", "Bonus", "Overtime"]),
            ("Hustle", "bolt.fill", .income, .investment, ["Freelance", "Consulting", "Side Project", "Sales", "Platform"]),
            ("Investment", "chart.line.uptrend.xyaxis", .income, .investment, ["Dividends", "Interest", "Real Estate", "Crypto"]),
            ("Grants", "graduationcap.fill", .income, .investment, ["Scholarship","Grants","Stipend"]),
            ("Allowance", "gift.fill", .income, .uncategorized, ["Government", "Red Packet", "Parental","Other"])
        ]
        
        let descriptor = FetchDescriptor<CategoryEntity>()
        let existing = (try? context.fetch(descriptor)) ?? []
        
        for target in targets {
            // Match by Name AND Type
            if let match = existing.first(where: { $0.name == target.name && $0.type == target.type.rawValue }) {
                // Category exists, check subcategories
                var updated = false
                for sub in target.subs {
                    if !match.subcategories.contains(sub) {
                        match.subcategories.append(sub)
                        updated = true
                    }
                }
                if updated { print("DataManager: Updated subcategories for \(target.name)") }
            } else {
                // Create new category
                let newCat = CategoryEntity(
                    name: target.name,
                    icon: target.icon,
                    type: target.type,
                    mappedCategory: target.map,
                    subcategories: target.subs,
                    sortOrder: 10 + existing.count // Append to end
                )
                context.insert(newCat)
                print("DataManager: Created missing category \(target.name)")
            }
        }
        
        try? context.save()
        print("DataManager: Categories seeded/ensured.")
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
