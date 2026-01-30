import Foundation
import SwiftData

struct CSVExportService {
    
    /// Generates a CSV string from transactions.
    /// Schema: ID, DateTime, Type, Category, Subcategory, Amount, Currency, Note, SourceAccount, DestinationAccount, Fees, Units, PricePerUnit
    /// - Parameters:
    ///   - transactions: The transactions to export
    ///   - assets: Asset entities for looking up asset types (Stock/Crypto)
    static func generateCSV(from transactions: [Transaction], assets: [AssetEntity] = []) -> String {
        // Build asset lookup dictionary for efficient access
        var assetLookup: [UUID: AssetEntity] = [:]
        for asset in assets {
            assetLookup[asset.id] = asset
        }
        
        // Header row (BOM will be added in SettingsView for proper encoding)
        var csv = "ID,DateTime,Type,Category,Subcategory,Amount,Currency,Note,SourceAccount,DestinationAccount,Fees,Units,PricePerUnit\n"
        
        let dateFormatter = ISO8601DateFormatter()
        
        for tx in transactions {
            let id = tx.id.uuidString
            let date = dateFormatter.string(from: tx.date)
            let type = tx.type.rawValue
            // Use categoryName (e.g. "Food") if present, otherwise fall back to engine map (e.g. "Survival")
            let category = escapeCSV(tx.categoryName.isEmpty ? tx.category.rawValue : tx.categoryName)
            let subcategory = escapeCSV(tx.subcategory)
            let amount = "\(tx.amount)"
            let currency = tx.currency
            let note = escapeCSV(tx.contextTags.joined(separator: "; ")) // Combine tags into note column
            
            // Mapping Logic based on Type
            var sourceAccount = ""
            var destAccount = ""
            
            // Logic to override Category/Subcategory for consistency per user request
            var finalCategory = category
            var finalSubcategory = subcategory
            
            if tx.type == .transfer {
                // User Requirement: Category and Subcategory should be "Transfer" for Bank transfers
                finalCategory = "Transfer"
                finalSubcategory = "Transfer"
                
                sourceAccount = tx.linkedAccountID ?? ""
                destAccount = tx.destinationAccountID ?? ""
            } else if tx.type == .assetPurchase {
                // User Requirement: Source should be money moving out (Payment Account)
                // Destination should be target asset ID
                sourceAccount = tx.linkedAccountID ?? ""
                destAccount = tx.targetAssetID?.uuidString ?? ""
                
                // Determine asset type (Stock or Crypto) from asset lookup
                if let assetID = tx.targetAssetID, let asset = assetLookup[assetID] {
                    switch asset.type {
                    case .stock:
                        finalCategory = "Stock"
                    case .crypto:
                        finalCategory = "Crypto"
                    default:
                        finalCategory = "Stock" // Default fallback
                    }
                } else {
                    // Fallback if asset not found
                    finalCategory = "Stock"
                }
                finalSubcategory = "Buy"
            } else {
                // Income / Expense
                sourceAccount = tx.linkedAccountID ?? ""
                destAccount = tx.destinationAccountID ?? ""
            }
            
            let fees = tx.fees.map { "\($0)" } ?? ""
            let units = tx.units.map { "\($0)" } ?? ""
            let price = tx.pricePerUnit.map { "\($0)" } ?? ""
            
            let line = "\(id),\(date),\(type),\(escapeCSV(finalCategory)),\(escapeCSV(finalSubcategory)),\(amount),\(currency),\(note),\(escapeCSV(sourceAccount)),\(escapeCSV(destAccount)),\(fees),\(units),\(price)\n"
            csv += line
        }
        
        return csv
    }
    
    private static func escapeCSV(_ text: String) -> String {
        if text.contains(",") || text.contains("\"") || text.contains("\n") {
            let escaped = text.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return text
    }
}
