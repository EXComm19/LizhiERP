import Foundation
import FirebaseAILogic

struct FinancialForecast: Codable {
    var estimatedFireDate: Date
    var lifestyleCreepIndex: Double
    var actionableInsights: [String]
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
        You are 'The Oracle', a financial genius AI.
        
        Analyze the following financial data:
        Transactions:
        \(txString)
        
        Assets:
        \(assetString)
        
        Task:
        1. Analyze spending velocity vs. investment growth.
        2. Project the FIRE (Financial Independence, Retire Early) date.
        3. Calculate a 'Lifestyle Creep Index' (0.0 to 1.0), where 1.0 is alarming growth in survival spending.
        4. Generate actionable insights to accelerate FIRE.
        
        Return ONLY valid JSON matching this schema:
        {
          "estimatedFireDate": "ISO8601 Date String",
          "lifestyleCreepIndex": 0.5,
          "actionableInsights": ["Insight 1", "Insight 2"]
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
        decoder.dateDecodingStrategy = .iso8601
        
        return try decoder.decode(FinancialForecast.self, from: data)
    }
}
