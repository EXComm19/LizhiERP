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
    @Attribute(.unique) var id: UUID
    var amount: Decimal
    var type: TransactionType
    var category: TransactionCategory
    var source: TransactionSource
    var date: Date
    var contextTags: [String]
    
    var subcategory: String // Specifics like "Food", "Taxi", "Rent"
    var linkedAssetID: UUID? // Link to AssetEntity (e.g. which wallet paid)
    var currency: String = "AUD" // Default currency
    
    var isActiveIncome: Bool {
        // Simplified: All income types count towards "Active Income" for now
        // This fixes the issue where CSV imported data defaults to "Spending" source and gets ignored.
        return type == .income
    }
    
    init(id: UUID = UUID(), amount: Decimal, type: TransactionType, category: TransactionCategory, source: TransactionSource, date: Date = Date(), contextTags: [String] = [], subcategory: String = "", linkedAssetID: UUID? = nil, currency: String = "AUD") {
        self.id = id
        self.amount = amount
        self.type = type
        self.category = category
        self.source = source
        self.date = date
        self.contextTags = contextTags
        self.subcategory = subcategory
        self.linkedAssetID = linkedAssetID
        self.currency = currency
    }
    
    enum CodingKeys: String, CodingKey {
        case id, amount, type, category, source, date, contextTags, subcategory, linkedAssetID, currency
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        amount = try container.decode(Decimal.self, forKey: .amount)
        type = try container.decode(TransactionType.self, forKey: .type)
        category = try container.decode(TransactionCategory.self, forKey: .category)
        source = try container.decode(TransactionSource.self, forKey: .source)
        date = try container.decode(Date.self, forKey: .date)
        contextTags = try container.decode([String].self, forKey: .contextTags)
        subcategory = try container.decodeIfPresent(String.self, forKey: .subcategory) ?? ""
        linkedAssetID = try container.decodeIfPresent(UUID.self, forKey: .linkedAssetID)
        currency = try container.decodeIfPresent(String.self, forKey: .currency) ?? "AUD"
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(amount, forKey: .amount)
        try container.encode(type, forKey: .type)
        try container.encode(category, forKey: .category)
        try container.encode(source, forKey: .source)
        try container.encode(date, forKey: .date)
        try container.encode(contextTags, forKey: .contextTags)
        try container.encode(subcategory, forKey: .subcategory)
        try container.encode(subcategory, forKey: .subcategory)
        try container.encode(linkedAssetID, forKey: .linkedAssetID)
        try container.encode(currency, forKey: .currency)
    }
}
