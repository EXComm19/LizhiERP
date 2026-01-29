import Foundation
import SwiftData

struct CSVExportService {
    
    /// Generates a CSV string from transactions.
    /// Schema: ID, DateTime, Type, Category, Subcategory, Amount, Currency, Note
    static func generateCSV(from transactions: [Transaction]) -> String {
        // Add UTF-8 BOM for Excel compatibility with Chinese characters
        var csv = "\u{FEFF}ID,DateTime,Type,Category,Subcategory,Amount,Currency,Note\n"
        
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
            
            let line = "\(id),\(date),\(type),\(category),\(subcategory),\(amount),\(currency),\(note)\n"
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
