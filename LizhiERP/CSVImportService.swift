import Foundation
import SwiftData

struct CSVImportService {
    
    struct ImportResult {
        var transactions: [Transaction]
        var errors: [String]
    }
    
    /// Parses a CSV string and returns a list of Transactions.
    /// Schema: ID, DateTime, Type, Category, Subcategory, Amount, Currency, Note
    static func processCSV(content: String) async -> ImportResult {
        var transactions: [Transaction] = []
        var errors: [String] = []
        
        var headers: [String] = []
        var idIndex = -1
        var dateIndex = -1
        var typeIndex = -1
        var categoryIndex = -1
        var subIndex = -1
        var amountIndex = -1
        var currencyIndex = -1
        var noteIndex = -1
        
        var isHeader = true
        var rowIndex = 1 // 1-based for errors
        
        // Use enumerateLines for streaming-like processing to save memory
        content.enumerateLines { line, stop in
            if line.isEmpty { return }
            
            if isHeader {
                headers = line.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                
                idIndex = headers.firstIndex(where: { $0.contains("id") }) ?? -1
                dateIndex = headers.firstIndex(where: { $0.contains("date") || $0.contains("time") }) ?? -1
                typeIndex = headers.firstIndex(where: { $0.contains("type") }) ?? -1
                categoryIndex = headers.firstIndex(where: { $0 == "category" }) ?? -1
                subIndex = headers.firstIndex(where: { $0.contains("sub") }) ?? -1
                amountIndex = headers.firstIndex(where: { $0.contains("amount") || $0.contains("value") }) ?? -1
                currencyIndex = headers.firstIndex(where: { $0.contains("cur") }) ?? -1
                noteIndex = headers.firstIndex(where: { $0.contains("note") || $0.contains("desc") }) ?? -1
                
                isHeader = false
            } else {
                rowIndex += 1
                
                let columns = line.components(separatedBy: ",")
                
                func col(_ idx: Int) -> String? {
                    guard idx >= 0, idx < columns.count else { return nil }
                    return columns[idx].trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "\"", with: "")
                }
                
                // 1. Resolve ID
                let rawID = col(idIndex) ?? ""
                let stableID = UUID(uuidString: rawID) ?? UUID()
                
                // 2. Resolve Date
                let rawDate = col(dateIndex) ?? ""
                let date = parseDate(rawDate)
                
                // 3. Resolve Amount
                let rawAmount = col(amountIndex)?.replacingOccurrences(of: "$", with: "") ?? "0"
                if let amountDouble = Double(rawAmount) {
                     let amount = Decimal(amountDouble)
                     
                     // 4. Resolve Type
                     let rawType = col(typeIndex)?.lowercased() ?? ""
                     let type: TransactionType
                     if rawType.contains("income") { type = .income }
                     else if rawType.contains("transfer") { type = .transfer }
                     else if rawType.contains("asset") { type = .assetPurchase }
                     else { type = .expense }
                     
                     // 5. Category
                     let rawCat = col(categoryIndex) ?? ""
                     let category = mapCategory(rawCat)
                     
                     // 6. Subcategory & Note & Currency
                     let subcategory = col(subIndex) ?? ""
                     let currency = col(currencyIndex) ?? "AUD"
                     let note = col(noteIndex) ?? ""
                     
                     var contextTags: [String] = []
                     if !note.isEmpty { contextTags.append(note) }
                     
                     let tx = Transaction(
                         id: stableID,
                         amount: amount,
                         type: type,
                         category: category,
                         source: .spending, // Default
                         date: date,
                         contextTags: contextTags,
                         subcategory: subcategory,
                         currency: currency
                     )
                     transactions.append(tx)
                } else {
                    errors.append("Row \(rowIndex): Invalid amount '\(rawAmount)'")
                }
            }
        }
        
        if transactions.isEmpty && errors.isEmpty && rowIndex == 1 {
             return ImportResult(transactions: [], errors: ["Empty CSV"])
        }
        
        return ImportResult(transactions: transactions, errors: errors)
    }
    
    private static func parseDate(_ string: String) -> Date {
        let raw = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.isEmpty { return Date() }
        
        // 1. ISO8601
        if let date = ISO8601DateFormatter().date(from: raw) { return date }
        
        // 2. Standard Formats
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        // Need to be flexible
        let formats = [
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd",
            "dd/MM/yyyy",
            "MM/dd/yyyy",
            "dd-MM-yyyy"
        ]
        
        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: raw) { return date }
        }
        
        // 3. Try generic ISO strategy for fractional seconds often found in systems
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = isoFormatter.date(from: raw) { return date }
        
        print("Warning: Could not parse date '\(raw)', defaulting to now.")
        return Date() // Fallback to now
    }
    
    private static func mapCategory(_ raw: String) -> TransactionCategory {
        let lower = raw.lowercased()
        if lower.contains("survival") { return .survival }
        if lower.contains("material") { return .material }
        if lower.contains("experient") { return .experiential } // 'experiential'
        if lower.contains("invest") { return .investment }
        
        // Fallback fuzzy matching if not strict enum string
        if lower.contains("rent") || lower.contains("grocer") || lower.contains("food") { return .survival }
        if lower.contains("shop") || lower.contains("iphone") { return .material }
        if lower.contains("travel") || lower.contains("movie") { return .experiential }
        
        return .uncategorized
    }
}
