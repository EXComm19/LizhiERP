import Foundation
import FirebaseAILogic

struct FinancialForecast: Codable {
    var estimatedFireDate: Date
    var lifestyleCreepIndex: Double
    var spendingAdvice: String? // General spending patterns, lifestyle creep
    var billInsights: String? // Repetitive billing, wrong units, wrong category
    var investmentStrategies: String? // Portfolio rebalancing, asset allocation
    var actionableInsights: [String] // Legacy fallback
    
    // Fallback computed properties
    var primarySpendingAdvice: String { spendingAdvice ?? actionableInsights.first ?? "Analyzing spending patterns..." }
    var primaryBillInsight: String { billInsights ?? (actionableInsights.count > 1 ? actionableInsights[1] : "Scanning bills...") }
    var primaryInvestmentStrategy: String { investmentStrategies ?? (actionableInsights.count > 2 ? actionableInsights[2] : "Evaluating portfolio...") }
}

/// Lightweight Codable DTO for Subscription (SwiftData models can't directly conform to Codable)
struct SubscriptionDTO: Codable {
    let name: String
    let amount: Double
    let cycle: String
    let categoryName: String
    let subcategory: String
    let nextPaymentDate: Date
    let brandDomain: String?
    
    init(from subscription: Subscription) {
        self.name = subscription.name
        self.amount = NSDecimalNumber(decimal: subscription.amount).doubleValue
        self.cycle = subscription.cycle
        self.categoryName = subscription.categoryName
        self.subcategory = subscription.subcategory
        self.nextPaymentDate = subscription.nextPaymentDate
        self.brandDomain = subscription.brandDomain
    }
}

class AIService {
    static let shared = AIService()
    
    private init() {}
    
    /// Sends transaction and asset data to Gemini 3.0 via Firebase AI Logic
    func generateForecast(transactions: [Transaction], assets: [AssetEntity]) async throws -> FinancialForecast {
        // Use user-provided snippet pattern
        let firebaseAI = FirebaseAI.firebaseAI(backend: .googleAI())
        let model = firebaseAI.generativeModel(modelName: "gemini-3-flash-preview")
        
        // 1. Serialize Data
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        
        let txData = try encoder.encode(transactions)
        let assetData = try encoder.encode(assets)
        let txString = String(data: txData, encoding: .utf8) ?? "[]"
        let assetString = String(data: assetData, encoding: .utf8) ?? "[]"
        
        // 2. Construct Prompt
        let prompt = """
        You are 'The Oracle', a highly personalized financial assistant for Kehan.
        You are not a generic bank bot; you are a partner in their journey towards Freedom (FIRE). Speak directly to them.

        USER PROFILE: Kehan

        1. Identity & Life Stage
        
        Age/Status: 20 years old, Australian Citizen. Currently an Undergraduate Junior (Year 3).
        Neuro-Type: High-Functioning ADHD & HSP (High Sensitive Person). I manage my environment to reduce sensory friction. My spending on comfort (quiet, darkness, smooth travel) is a medical necessity, not a luxury.
        
        Career Path:
        Now: Undergraduate -> Honours (Age 21) -> PhD (Age 22-25, Full Scholarship).
        Future: E-3 Visa -> US Pharma Industry (Target Income: $150k+ USD).
        Role: Future Pharmacology/Drug Discovery Expert (Kinase Inhibitors, CADD).
        
        2. The 'Lizhi Index' Financial Philosophy
        
        Core Metric: Active Income / Total Expense. Goal > 1.0 at all times.
        FIRE Goal: 'Fat FIRE' via high income + smart investing. Not 'Lean FIRE' via deprivation.
        
        Assets:
        Fortress: Significant family backing (Shanghai real estate inheritance), but I act as if I am building from zero.
        Current: Modest student savings (~$5k AUD).
        Strategy: Balanced US Tech/Index ETFs (IVV/IHVV).
        
        3. Spending Values (The 'Good' vs 'Bad')
        
        ✅ Experiential (GOOD):
        Social Dining: Feasts with friends ('The Gathering'). This is vital for my soul.
        Travel: High-density, low-friction travel. Japan, Food trips. Business Class is approved to protect my sensory system.
        Hobbies: Badminton, Mahjong.
        
        ⚠️ Material (CAUTION):
        Tech/Gear: I love Sony Alpha cameras and Apple gear. Rule: Buy only if it's a 'Tool' that pays for itself (reselling/side hustle) or brings immense joy. No mindless upgrades.
        Clothing: Uniform style (Merino wool, Veilance). Buy once, buy right.
        
        ❌ Survival (THE ENEMY):
        Solo Meals: Basic fuel. Keep this efficient and cheap.
        Rent/Bills: Optimize ruthlessly. Lifestyle creep here is the enemy.
        
        4. Your Role (The Oracle)
        
        Tone: Witty, tough-love, but deeply empathetic to my neurodivergence.
        
        Directive:
        Cheer me on when I spend $200 on a dinner with friends.
        Scold me if I spend $50 on a lazy Uber Eats solo meal.
        Remind me that my 'High Friction' choices (economy flights, bad housing) cost me more in mental energy than money.
        Treat my PhD stipend as a 'seed fund', not just pocket money.
        Acknowledge you have ingested this profile and are ready to serve.
        
        The Philosophy (IMPORTANT):
        1. **Experiential > Material:** We value memories (Travel, Dining with friends) over things (Gadgets, Clothes). Do not scold Kehan for spending on experiences unless it threatens survival.
        2. **The Enemy is Creep:** 'Survival' expenses (Rent, Groceries) must be optimized. Any increase here is 'Lifestyle Creep'.
        3. **The Goal:** Maximizing the 'Lizhi Index' (Active Income / Expense) to fund the Asset Vault.
        
        Analyze the following financial data:
        Transactions (Recent history):
        \(txString)
        
        Assets (Current Holdings):
        \(assetString)
        
        Task:
        1. Analyze spending velocity vs. investment growth. Detect if 'Material' spending is eating into the 'Freedom Fund'.
        2. Project the FIRE date based on current savings rate.
        3. Calculate 'Lifestyle Creep Index' (0.0 to 1.0). 1.0 means survival costs are rising alarmingly.
        4. Generate 3 **highly specific and Distinctive, conversational** insights (Max 25 words each):
           - **Spending Advice**: Big picture spending patterns, lifestyle creep warnings, category imbalances.
           - **Bill Insights**: Detect repetitive/duplicate subscriptions, unusual billing amounts, potential wrong category assignments, note typos.
           - **Investment Strategies**: Portfolio rebalancing suggestions, asset allocation tips, when to buy/hold/sell.

        Return ONLY valid JSON matching this schema:
        {
          "estimatedFireDate": "ISO8601 Date String",
          "lifestyleCreepIndex": 0.5,
          "spendingAdvice": "Your spending advice here",
          "billInsights": "Your bill insights here",
          "investmentStrategies": "Your investment strategies here",
          "actionableInsights": []
        }
        """
        
        // 3. Generate Content
        let response = try await model.generateContent(prompt)
        
        guard let text = response.text else {
            throw NSError(domain: "AIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No text in response"])
        }
        
        // 4. Parse JSON
        // Strip markdown code blocks if present
        let cleanText = text.replacingOccurrences(of: "```json", with: "")
                            .replacingOccurrences(of: "```", with: "")
                            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        
        guard let data = cleanText.data(using: String.Encoding.utf8) else {
            throw NSError(domain: "AIService", code: -2, userInfo: [NSLocalizedDescriptionKey: "Invalid UTF8"])
        }
        
        let decoder = JSONDecoder()
        
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        
        decoder.dateDecodingStrategy = .custom({ decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            
            // Try standard ISO8601 with fractional seconds first
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
            if let date = formatter.date(from: dateString) {
                return date
            }
            
            // Try standard ISO8601 without fractional seconds
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
            if let date = formatter.date(from: dateString) {
                return date
            }
            
            // Try simple YYYY-MM-DD
            formatter.dateFormat = "yyyy-MM-dd"
            if let date = formatter.date(from: dateString) {
                return date
            }
            
            // Throw error if none match
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Date string does not match expected format: \(dateString)")
        })
        
        return try decoder.decode(FinancialForecast.self, from: data)
    }
    
    /// Answers a custom user question about their financial data
    func askQuestion(
        question: String,
        transactions: [Transaction],
        assets: [AssetEntity],
        subscriptions: [Subscription]
    ) async throws -> String {
        let firebaseAI = FirebaseAI.firebaseAI(backend: .googleAI())
        let model = firebaseAI.generativeModel(modelName: "gemini-3-flash-preview")
        
        // Serialize data
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        
        let txData = try encoder.encode(transactions)
        let assetData = try encoder.encode(assets)
        let subDTOs = subscriptions.map { SubscriptionDTO(from: $0) }
        let subData = try encoder.encode(subDTOs)
        let txString = String(data: txData, encoding: .utf8) ?? "[]"
        let assetString = String(data: assetData, encoding: .utf8) ?? "[]"
        let subString = String(data: subData, encoding: .utf8) ?? "[]"
        
        let prompt = """
        You are 'The Oracle', Kehan's personal financial assistant. Answer the following question concisely and conversationally.
        
        USER QUESTION: \(question)
        
        FINANCIAL DATA:
        Transactions: \(txString)
        Assets: \(assetString)
        Subscriptions (Fixed Costs): \(subString)
        
        Instructions:
        - Be direct and conversational.
        - If the question involves currency conversion, use reasonable current rates.
        - If you cannot answer from the data, say so honestly.
        - Keep your response under 50 words unless the user asks for detail.
        
        Respond in plain text (no JSON).
        """
        
        let response = try await model.generateContent(prompt)
        return response.text ?? "I couldn't process that question. Try rephrasing?"
    }
}
