import Foundation
import Combine
import SwiftUI

/// Currency Conversion Service using the Frankfurter API
/// API Documentation: https://api.frankfurter.dev
/// Free, open-source, no API keys required
class CurrencyService: ObservableObject {
    static let shared = CurrencyService()
    
    // MARK: - User Defaults Keys
    private let kBaseCurrency = "LizhiERP_BaseCurrency"
    private let kCachedRates = "LizhiERP_CachedRates"
    private let kLastFetchDate = "LizhiERP_LastFetchDate"
    
    // MARK: - Published Properties
    @Published var baseCurrency: String {
        didSet {
            UserDefaults.standard.set(baseCurrency, forKey: kBaseCurrency)
            // Refetch rates when base currency changes
            Task { await fetchLatestRates() }
        }
    }
    
    @Published var isLoading: Bool = false
    @Published var lastUpdated: Date?
    @Published var error: String?
    
    // MARK: - Exchange Rates (Base: EUR from API, converted internally)
    // Stored as [CurrencyCode: Rate relative to EUR]
    private var rates: [String: Double] = [:]
    
    // Fallback rates if API fails (Base: USD)
    private let fallbackRates: [String: Double] = [
        "USD": 1.0,
        "AUD": 1.58,
        "CNY": 7.25,
        "EUR": 0.92,
        "GBP": 0.79,
        "JPY": 151.0,
        "SGD": 1.34,
        "HKD": 7.82,
        "NZD": 1.63,
        "CAD": 1.35,
        "CHF": 0.88,
        "BRL": 5.0,
        "KRW": 1350.0,
        "INR": 83.0
    ]
    
    // MARK: - Supported Currencies
    let availableCurrencies = ["AUD", "USD", "CNY", "EUR", "GBP", "JPY", "SGD", "HKD", "NZD", "CAD", "CHF", "BRL", "KRW", "INR"]
    
    // MARK: - API Configuration
    private let baseURL = "https://api.frankfurter.dev/v1"
    
    // MARK: - Init
    private init() {
        self.baseCurrency = UserDefaults.standard.string(forKey: kBaseCurrency) ?? "AUD"
        loadCachedRates()
        
        // Fetch fresh rates on init
        Task { await fetchLatestRates() }
    }
    
    // MARK: - API Response Models
    struct LatestRatesResponse: Codable {
        let base: String
        let date: String
        let rates: [String: Double]
    }
    
    struct CurrenciesResponse: Codable {
        // Dictionary of currency code to full name
        // e.g. "AUD": "Australian Dollar"
    }
    
    // MARK: - Public API
    
    /// Fetches the latest exchange rates from Frankfurter API
    @MainActor
    func fetchLatestRates() async {
        guard !isLoading else { return }
        
        // Check if we already fetched today
        if let lastFetch = lastUpdated, Calendar.current.isDateInToday(lastFetch) {
            print("CurrencyService: Rates already fetched today, skipping.")
            return
        }
        
        isLoading = true
        error = nil
        
        do {
            // Fetch rates with EUR as base (API default)
            // We'll convert to user's base currency internally
            let url = URL(string: "\(baseURL)/latest")!
            
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                throw URLError(.badServerResponse)
            }
            
            let decoded = try JSONDecoder().decode(LatestRatesResponse.self, from: data)
            
            // Store rates (base is EUR)
            self.rates = decoded.rates
            self.rates["EUR"] = 1.0 // EUR is the base
            
            // Cache the rates
            cacheRates()
            
            self.lastUpdated = Date()
            UserDefaults.standard.set(self.lastUpdated, forKey: kLastFetchDate)
            
            print("CurrencyService: Successfully fetched rates for \(decoded.date). \(rates.count) currencies available.")
            
        } catch {
            print("CurrencyService: Failed to fetch rates - \(error.localizedDescription)")
            self.error = error.localizedDescription
            
            // Use fallback rates if we have no cached rates
            if rates.isEmpty {
                useFallbackRates()
            }
        }
        
        isLoading = false
    }
    
    /// Fetches historical rates for a specific date
    func fetchHistoricalRates(for date: Date) async -> [String: Double]? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: date)
        
        do {
            let url = URL(string: "\(baseURL)/\(dateString)")!
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                throw URLError(.badServerResponse)
            }
            
            let decoded = try JSONDecoder().decode(LatestRatesResponse.self, from: data)
            var historicalRates = decoded.rates
            historicalRates["EUR"] = 1.0
            return historicalRates
            
        } catch {
            print("CurrencyService: Failed to fetch historical rates for \(dateString) - \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Returns the symbol for a given currency code
    func symbol(for code: String) -> String {
        let locale = NSLocale(localeIdentifier: code)
        return locale.displayName(forKey: .currencySymbol, value: code) ?? code
    }
    
    /// Returns the full name of a currency
    func name(for code: String) -> String {
        let locale = Locale(identifier: code)
        return locale.localizedString(forCurrencyCode: code) ?? code
    }
    
    /// Converts an amount from one currency to another using latest rates
    func convert(_ amount: Decimal, from sourceCurrency: String, to targetCurrency: String) -> Decimal {
        if sourceCurrency == targetCurrency { return amount }
        
        // If rates are empty, use fallback
        let effectiveRates = rates.isEmpty ? fallbackRates : rates
        
        // Frankfurter returns EUR-based rates
        // To convert from A to B:
        // 1. Convert A to EUR: amount / rate[A]
        // 2. Convert EUR to B: eurAmount * rate[B]
        
        guard let sourceRate = effectiveRates[sourceCurrency],
              let targetRate = effectiveRates[targetCurrency] else {
            print("CurrencyService: Missing rate for \(sourceCurrency) or \(targetCurrency)")
            return amount // Return unchanged if rates missing
        }
        
        // Edge case: if using fallback rates (USD-based), adjust logic
        if rates.isEmpty {
            // Fallback rates are USD-based
            let usdValue = amount / Decimal(sourceRate)
            return usdValue * Decimal(targetRate)
        }
        
        // API rates are EUR-based
        let eurValue = amount / Decimal(sourceRate)
        return eurValue * Decimal(targetRate)
    }
    
    /// Converts an amount to the user's selected Base Currency
    func convertToBase(_ amount: Decimal, from sourceCurrency: String) -> Decimal {
        return convert(amount, from: sourceCurrency, to: baseCurrency)
    }
    
    /// Get the exchange rate between two currencies
    func getRate(from sourceCurrency: String, to targetCurrency: String) -> Double? {
        if sourceCurrency == targetCurrency { return 1.0 }
        
        let effectiveRates = rates.isEmpty ? fallbackRates : rates
        
        guard let sourceRate = effectiveRates[sourceCurrency],
              let targetRate = effectiveRates[targetCurrency] else {
            return nil
        }
        
        if rates.isEmpty {
            // USD-based fallback
            return targetRate / sourceRate
        }
        
        // EUR-based API rates
        return targetRate / sourceRate
    }
    
    // MARK: - Caching
    
    private func cacheRates() {
        if let encoded = try? JSONEncoder().encode(rates) {
            UserDefaults.standard.set(encoded, forKey: kCachedRates)
        }
    }
    
    private func loadCachedRates() {
        if let data = UserDefaults.standard.data(forKey: kCachedRates),
           let decoded = try? JSONDecoder().decode([String: Double].self, from: data) {
            self.rates = decoded
            self.lastUpdated = UserDefaults.standard.object(forKey: kLastFetchDate) as? Date
            print("CurrencyService: Loaded \(rates.count) cached rates")
        } else {
            print("CurrencyService: No cached rates, will fetch fresh")
        }
    }
    
    private func useFallbackRates() {
        // Convert fallback (USD-based) to EUR-based for consistency
        // This is approximate but better than nothing
        self.rates = fallbackRates
        print("CurrencyService: Using fallback rates")
    }
    
    // MARK: - Force Refresh
    
    @MainActor
    func forceRefresh() async {
        lastUpdated = nil // Clear the date check
        await fetchLatestRates()
    }
}
