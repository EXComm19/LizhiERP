import SwiftData
import Foundation

@Model
final class CategoryEntity {
    var name: String
    var icon: String
    var type: String // Stored as String for Predicate compatibility
    var mappedCategory: TransactionCategory // The "High Level" category (Survival, Material, etc)
    var subcategories: [String]
    var sortOrder: Int
    
    // Computed helper
    var transactionType: TransactionType {
        TransactionType(rawValue: type) ?? .expense
    }
    
    init(name: String, icon: String, type: TransactionType, mappedCategory: TransactionCategory, subcategories: [String] = [], sortOrder: Int = 0) {
        self.name = name
        self.icon = icon
        self.type = type.rawValue
        self.mappedCategory = mappedCategory
        self.subcategories = subcategories
        self.sortOrder = sortOrder
    }
}
