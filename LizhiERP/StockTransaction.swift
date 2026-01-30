import Foundation
import SwiftData

@Model
final class StockTransaction {
    @Attribute(.unique) var id: UUID
    var assetID: UUID // Foreign key to AssetEntity
    var transactionID: UUID? // Link to parent Transaction (prevents duplicates on edit)
    var type: StockTransactionType
    var units: Decimal
    var pricePerUnit: Decimal
    var fees: Decimal
    var date: Date
    var notes: String
    var currency: String
    
    // Computed: Total cost for buy, total proceeds for sell
    var totalAmount: Decimal {
        return (pricePerUnit * units) + fees
    }
    
    init(
        id: UUID = UUID(),
        assetID: UUID,
        transactionID: UUID? = nil,
        type: StockTransactionType,
        units: Decimal,
        pricePerUnit: Decimal,
        fees: Decimal = 0,
        date: Date = Date(),
        notes: String = "",
        currency: String = "AUD"
    ) {
        self.id = id
        self.assetID = assetID
        self.transactionID = transactionID
        self.type = type
        self.units = units
        self.pricePerUnit = pricePerUnit
        self.fees = fees
        self.date = date
        self.notes = notes
        self.currency = currency
    }
}

enum StockTransactionType: String, Codable {
    case buy = "Buy"
    case sell = "Sell"
}
