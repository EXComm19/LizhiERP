import SwiftData
import Foundation

@Model
final class AssetEntity: Codable {
    @Attribute(.unique) var id: UUID
    var ticker: String // Symbol or Account Name
    var holdings: Decimal
    var marketValue: Decimal // Unitary price for Stocks/Crypto. Unused for Cash now.
    var lastUpdated: Date
    
    var type: AssetType
    var currency: String = "AUD"
    
    // Bank Account Features
    var customID: String?       // User defined ID (e.g. "CBA", "AMEX")
    var initialBalance: Decimal // Opening balance for accounts
    var cashBalance: Decimal?   // [NEW] Explicit balance for Cash assets
    
    var isPassiveIncomeSource: Bool {
        return type == .stock || type == .crypto || type == .other
    }
    
    init(id: UUID = UUID(), ticker: String, holdings: Decimal, marketValue: Decimal, type: AssetType = .stock, currency: String = "AUD", lastUpdated: Date = Date(), customID: String? = nil, initialBalance: Decimal = 0, cashBalance: Decimal? = nil) {
        self.id = id
        self.ticker = ticker
        self.holdings = holdings
        self.marketValue = marketValue
        self.type = type
        self.currency = currency
        self.lastUpdated = lastUpdated
        self.customID = customID
        self.initialBalance = initialBalance
        self.cashBalance = cashBalance
    }
    
    var totalValue: Decimal {
        if type == .cash { 
            return cashBalance ?? marketValue // Fallback for migration
        }
        return holdings * marketValue
    }
    
    enum CodingKeys: String, CodingKey {
        case id, ticker, holdings, marketValue, lastUpdated, type, currency, customID, initialBalance, cashBalance
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        ticker = try container.decode(String.self, forKey: .ticker)
        holdings = try container.decode(Decimal.self, forKey: .holdings)
        marketValue = try container.decode(Decimal.self, forKey: .marketValue)
        lastUpdated = try container.decode(Date.self, forKey: .lastUpdated)
        type = try container.decode(AssetType.self, forKey: .type)
        currency = try container.decodeIfPresent(String.self, forKey: .currency) ?? "AUD"
        customID = try container.decodeIfPresent(String.self, forKey: .customID)
        initialBalance = try container.decodeIfPresent(Decimal.self, forKey: .initialBalance) ?? 0
        cashBalance = try container.decodeIfPresent(Decimal.self, forKey: .cashBalance)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(ticker, forKey: .ticker)
        try container.encode(holdings, forKey: .holdings)
        try container.encode(marketValue, forKey: .marketValue)
        try container.encode(lastUpdated, forKey: .lastUpdated)
        try container.encode(type, forKey: .type)
        try container.encode(currency, forKey: .currency)
        try container.encode(customID, forKey: .customID)
        try container.encode(initialBalance, forKey: .initialBalance)
        try container.encode(cashBalance, forKey: .cashBalance)
    }
}

enum AssetType: String, Codable, CaseIterable {
    case cash = "Cash"          // Physical Cash, Bank Accounts
    case stock = "Stock"        // ETFs, Stocks
    case crypto = "Crypto"
    case other = "Other"
}
