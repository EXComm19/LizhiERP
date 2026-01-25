import SwiftData
import Foundation

enum TransactionType: String, Codable, CaseIterable {
    case income = "Income"
    case expense = "Expense"
    case transfer = "Transfer"
    case assetPurchase = "Asset Purchase"
}

enum TransactionCategory: String, Codable, CaseIterable {
    case survival = "Survival"          // Rent, Groceries (Needs)
    case material = "Material"          // Gadgets, Clothes (Wants)
    case experiential = "Experiential"  // Travel, Dining (Soul)
    case investment = "Investment"      // Putting money to work
    case uncategorized = "Uncategorized"
}

enum TransactionSource: String, Codable, CaseIterable {
    case job = "Job"                    // Salary
    case sideProject = "Side Project"   // Indie hacking
    case investment = "Investment"      // Dividends, Cap Gains
    case gift = "Gift"
    case spending = "Spending"          // Default for expenses
}

@Model
final class Transaction: Codable {
    var amount: Decimal
    var type: TransactionType
    var category: TransactionCategory
    var source: TransactionSource
    var date: Date
    var contextTags: [String]
    
    var subcategory: String // Specifics like "Food", "Taxi", "Rent"
    var linkedAssetID: UUID? // Link to AssetEntity (e.g. which wallet paid)
    
    var isActiveIncome: Bool {
        return type == .income && (source == .job || source == .sideProject)
    }
    
    init(amount: Decimal, type: TransactionType, category: TransactionCategory, source: TransactionSource, date: Date = Date(), contextTags: [String] = [], subcategory: String = "", linkedAssetID: UUID? = nil) {
        self.amount = amount
        self.type = type
        self.category = category
        self.source = source
        self.date = date
        self.contextTags = contextTags
        self.subcategory = subcategory
        self.linkedAssetID = linkedAssetID
    }
    
    enum CodingKeys: String, CodingKey {
        case amount, type, category, source, date, contextTags, subcategory, linkedAssetID
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        amount = try container.decode(Decimal.self, forKey: .amount)
        type = try container.decode(TransactionType.self, forKey: .type)
        category = try container.decode(TransactionCategory.self, forKey: .category)
        source = try container.decode(TransactionSource.self, forKey: .source)
        date = try container.decode(Date.self, forKey: .date)
        contextTags = try container.decode([String].self, forKey: .contextTags)
        subcategory = try container.decodeIfPresent(String.self, forKey: .subcategory) ?? ""
        linkedAssetID = try container.decodeIfPresent(UUID.self, forKey: .linkedAssetID)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(amount, forKey: .amount)
        try container.encode(type, forKey: .type)
        try container.encode(category, forKey: .category)
        try container.encode(source, forKey: .source)
        try container.encode(date, forKey: .date)
        try container.encode(contextTags, forKey: .contextTags)
        try container.encode(subcategory, forKey: .subcategory)
        try container.encode(linkedAssetID, forKey: .linkedAssetID)
    }
}
