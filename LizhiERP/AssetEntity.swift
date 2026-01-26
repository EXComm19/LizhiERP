import SwiftData
import Foundation

@Model
final class AssetEntity: Codable {
    @Attribute(.unique) var id: UUID
    var ticker: String // Symbol or Account Name
    var holdings: Decimal
    var marketValue: Decimal // Current unitary price or total balance? Let's say Total Balance for cash/accounts.
    var lastUpdated: Date
    
    var type: AssetType
    var currency: String = "AUD"
    
    var isPassiveIncomeSource: Bool {
        return type == .stock || type == .crypto || type == .other
    }
    
    init(id: UUID = UUID(), ticker: String, holdings: Decimal, marketValue: Decimal, type: AssetType = .stock, currency: String = "AUD", lastUpdated: Date = Date()) {
        self.id = id
        self.ticker = ticker
        self.holdings = holdings
        self.marketValue = marketValue // Interpreted as Total Value for Cash, Unit Price for Stocks? 
        // For simplicity towards user request "Soft assets including cash...", let's standardize:
        // For Cash/Accounts: Holdings = 1, MarketValue = Balance
        // For Stocks/Crypto: Holdings = Units, MarketValue = Unit Price
        // So Total Value = Holdings * MarketValue.
        self.type = type
        self.currency = currency
        self.lastUpdated = lastUpdated
    }
    
    var totalValue: Decimal {
        return holdings * marketValue
    }
    
    enum CodingKeys: String, CodingKey {
        case id, ticker, holdings, marketValue, lastUpdated, type, currency
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
    }
}

enum AssetType: String, Codable, CaseIterable {
    case cash = "Cash"          // Physical Cash, Bank Accounts
    case stock = "Stock"        // ETFs, Stocks
    case crypto = "Crypto"
    case other = "Other"
}
