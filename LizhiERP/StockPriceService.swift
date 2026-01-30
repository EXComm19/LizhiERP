import Foundation
import SwiftData

/// Service to fetch real-time stock prices using Financial Modeling Prep API
/// Replaces XCAStocksAPI which had Yahoo 401 issues
actor StockPriceService {
    
    /// Fetch current price for a single ticker
    /// - Parameter ticker: Stock symbol (e.g., "AAPL", "IVV.AX", "BTC-USD")
    /// - Returns: Current market price as Decimal
    func fetchCurrentPrice(ticker: String) async throws -> Decimal {
        let price = try await StockService.shared.fetchCurrentPrice(for: ticker)
        return Decimal(price)
    }
    
    /// Fetch prices for multiple tickers in batch
    /// - Parameter tickers: Array of stock symbols
    /// - Returns: Dictionary mapping ticker to current price
    func fetchBatchPrices(tickers: [String]) async throws -> [String: Decimal] {
        let prices = try await StockService.shared.fetchBatchPrices(for: tickers)
        var decimalPrices: [String: Decimal] = [:]
        for (symbol, price) in prices {
            decimalPrices[symbol] = Decimal(price)
        }
        return decimalPrices
    }
    
    /// Update an asset's market value with latest price
    /// - Parameter asset: AssetEntity to update
    func updateAssetPrice(asset: AssetEntity, context: ModelContext) async throws {
        let currentPrice = try await fetchCurrentPrice(ticker: asset.ticker)
        
        await MainActor.run {
            asset.marketValue = currentPrice
            asset.lastUpdated = Date()
            try? context.save()
            print("✅ Updated \(asset.ticker): $\(currentPrice)")
        }
    }
}

enum StockPriceError: Error, LocalizedError {
    case tickerNotFound
    case apiError(String)
    
    var errorDescription: String? {
        switch self {
        case .tickerNotFound:
            return "Stock ticker not found"
        case .apiError(let message):
            return "API Error: \(message)"
        }
    }
}


