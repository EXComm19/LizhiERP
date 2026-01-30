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
    var category: TransactionCategory  // Engine Map: Survival, Material, Experiential, Investment
    var source: TransactionSource
    var date: Date
    var contextTags: [String]
    
    var categoryName: String = ""       // Category from CSV: "Food", "Transport", "Shopping" (for pie chart)
    var subcategory: String = ""        // Subcategory within Category: "Groceries", "Dining Out", etc.
    var linkedAccountID: String?        // Link to AssetEntity via customID (e.g. "CBA")
    var currency: String = "AUD"        // Default currency
    
    // NEW FIELDS FOR TRANSFERS
    // NEW FIELDS FOR TRANSFERS
    var destinationAccountID: String?   // DESTINATION: Money goes INTO this Account (String ID)
    var targetAssetID: UUID?            // INVESTMENT: Money buys this Asset (UUID)
    var units: Decimal?                 // QUANTITY: How many shares/units bought
    var pricePerUnit: Decimal?          // PRICE: Price per share/unit at execution
    var fees: Decimal?                  // FEES: brokerage or transaction fees
    
    var isActiveIncome: Bool {
        // Simplified: All income types count towards "Active Income" for now
        return type == .income
    }
    
    init(id: UUID = UUID(), amount: Decimal, type: TransactionType, category: TransactionCategory, source: TransactionSource, date: Date = Date(), contextTags: [String] = [], categoryName: String = "", subcategory: String = "", linkedAccountID: String? = nil, currency: String = "AUD", destinationAccountID: String? = nil, targetAssetID: UUID? = nil, units: Decimal? = nil, pricePerUnit: Decimal? = nil, fees: Decimal? = nil) {
        self.id = id
        self.amount = amount
        self.type = type
        self.category = category
        self.source = source
        self.date = date
        self.contextTags = contextTags
        self.categoryName = categoryName
        self.subcategory = subcategory
        self.linkedAccountID = linkedAccountID
        self.currency = currency
        self.destinationAccountID = destinationAccountID
        self.targetAssetID = targetAssetID
        self.units = units
        self.pricePerUnit = pricePerUnit
        self.fees = fees
    }
    
    enum CodingKeys: String, CodingKey {
        case id, amount, type, category, source, date, contextTags, categoryName, subcategory, linkedAccountID, currency, destinationAccountID, targetAssetID, units, pricePerUnit, fees
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
        categoryName = try container.decodeIfPresent(String.self, forKey: .categoryName) ?? ""
        subcategory = try container.decodeIfPresent(String.self, forKey: .subcategory) ?? ""
        linkedAccountID = try container.decodeIfPresent(String.self, forKey: .linkedAccountID)
        currency = try container.decodeIfPresent(String.self, forKey: .currency) ?? "AUD"
        destinationAccountID = try container.decodeIfPresent(String.self, forKey: .destinationAccountID)
        targetAssetID = try container.decodeIfPresent(UUID.self, forKey: .targetAssetID)
        units = try container.decodeIfPresent(Decimal.self, forKey: .units)
        pricePerUnit = try container.decodeIfPresent(Decimal.self, forKey: .pricePerUnit)
        fees = try container.decodeIfPresent(Decimal.self, forKey: .fees)
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
        try container.encode(categoryName, forKey: .categoryName)
        try container.encode(subcategory, forKey: .subcategory)
        try container.encode(linkedAccountID, forKey: .linkedAccountID)
        try container.encode(currency, forKey: .currency)
        try container.encode(destinationAccountID, forKey: .destinationAccountID)
        try container.encode(targetAssetID, forKey: .targetAssetID)
        try container.encode(units, forKey: .units)
        try container.encode(pricePerUnit, forKey: .pricePerUnit)
        try container.encode(fees, forKey: .fees)
    }
}
