import Foundation

/// Service to fetch Stock/ETF/Crypto prices.
/// Provider: Yahoo Finance (Unofficial Chart Endpoint)
/// Status: Free, Supports ASX, No API Key required.
class StockService {
    static let shared = StockService()
    
    private init() {}
    
    /// Fetches the current price for a given ticker (e.g. "IVV.AX", "AAPL", "BTC-USD")
    func fetchCurrentPrice(for ticker: String) async throws -> Double {
        // We use the chart endpoint because it is often less restricted than the quote endpoint.
        // We request a 1-day range; the 'meta' block contains the current price.
        let urlString = "https://query1.finance.yahoo.com/v8/finance/chart/\(ticker)?interval=1d&range=1d"
        
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        
        // Use a customized request to look like a browser
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 10
        // Browsers often send these headers; sometimes helps avoid basic blocking
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15", forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        if httpResponse.statusCode != 200 {
            print("❌ Yahoo API Error: \(httpResponse.statusCode) for \(ticker)")
            throw URLError(.badServerResponse)
        }
        
        // Decode the specific Yahoo Chart JSON structure
        let result = try JSONDecoder().decode(YahooChartResponse.self, from: data)
        
        guard let meta = result.chart.result?.first?.meta else {
             throw NSError(domain: "StockService", code: 404, userInfo: [NSLocalizedDescriptionKey: "No data found for \(ticker)"])
        }
        
        print("✅ Fetched \(ticker): $\(meta.regularMarketPrice)")
        return meta.regularMarketPrice
    }
    
    /// Fetch prices for multiple tickers (fetches sequentially)
    func fetchBatchPrices(for tickers: [String]) async throws -> [String: Double] {
        var prices: [String: Double] = [:]
        for ticker in tickers {
            do {
                let price = try await fetchCurrentPrice(for: ticker)
                prices[ticker] = price
            } catch {
                print("⚠️ Failed to fetch \(ticker): \(error.localizedDescription)")
            }
        }
        return prices
    }
}

// MARK: - Yahoo JSON Models

struct YahooChartResponse: Codable {
    let chart: YahooChart
}

struct YahooChart: Codable {
    let result: [YahooChartResult]?
    let error: YahooChartError?
}

struct YahooChartResult: Codable {
    let meta: YahooChartMeta
}

struct YahooChartMeta: Codable {
    let currency: String
    let symbol: String
    let regularMarketPrice: Double
    let previousClose: Double?
    let regularMarketTime: Int?
}

struct YahooChartError: Codable {
    let code: String
    let description: String
}

