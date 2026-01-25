import SwiftData
import Foundation

enum PhysicalAssetStatus: String, Codable, CaseIterable {
    case active = "Active"
    case retired = "Retired"
    case sold = "Sold"
    case lost = "Lost"
}

@Model
final class PhysicalAsset: Codable {
    var name: String
    var purchaseValue: Decimal
    var purchaseDate: Date
    var category: String // e.g. "Camera", "Laptop", "Furniture"
    
    // Status
    var status: PhysicalAssetStatus
    var retiredDate: Date?
    
    // Insurance
    var isInsured: Bool
    var insuranceCostYearly: Decimal
    
    // Icon
    var icon: String // SF Symbol
    
    // Computed: Days Owned
    var daysOwned: Int {
        let end = retiredDate ?? Date()
        let components = Calendar.current.dateComponents([.day], from: purchaseDate, to: end)
        return max(1, components.day ?? 1)
    }
    
    // Computed: Cost Per Day (Excluding insurance for now, or adding it?)
    // Let's simple amortize purchase value / days.
    // Ideally we add insurance cost proportional to days owned too?
    // "Cost per day" usually means depreciation + running cost.
    // For simplicity: (Purchase Value + (InsuranceYearly/365 * Days)) / Days
    var costPerDay: Decimal {
        let days = Decimal(daysOwned)
        let dailyInsurance = insuranceCostYearly / 365.0
        let totalInsurancePaid = dailyInsurance * days
        
        // If retired/sold, we might want to subtract resale value? 
        // For now, assume sunk cost.
        let totalCost = purchaseValue + (isInsured ? totalInsurancePaid : 0)
        
        return totalCost / days
    }
    
    init(name: String, purchaseValue: Decimal, purchaseDate: Date, category: String = "General", status: PhysicalAssetStatus = .active, isInsured: Bool = false, insuranceCostYearly: Decimal = 0, icon: String = "cube.box.fill") {
        self.name = name
        self.purchaseValue = purchaseValue
        self.purchaseDate = purchaseDate
        self.category = category
        self.status = status
        self.isInsured = isInsured
        self.insuranceCostYearly = insuranceCostYearly
        self.icon = icon
    }
    
    // Codable implementation
    enum CodingKeys: String, CodingKey {
        case name, purchaseValue, purchaseDate, category, status, retiredDate, isInsured, insuranceCostYearly, icon
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        purchaseValue = try container.decode(Decimal.self, forKey: .purchaseValue)
        purchaseDate = try container.decode(Date.self, forKey: .purchaseDate)
        category = try container.decode(String.self, forKey: .category)
        status = try container.decode(PhysicalAssetStatus.self, forKey: .status)
        retiredDate = try container.decodeIfPresent(Date.self, forKey: .retiredDate)
        isInsured = try container.decode(Bool.self, forKey: .isInsured)
        insuranceCostYearly = try container.decode(Decimal.self, forKey: .insuranceCostYearly)
        icon = try container.decode(String.self, forKey: .icon)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(purchaseValue, forKey: .purchaseValue)
        try container.encode(purchaseDate, forKey: .purchaseDate)
        try container.encode(category, forKey: .category)
        try container.encode(status, forKey: .status)
        try container.encode(retiredDate, forKey: .retiredDate)
        try container.encode(isInsured, forKey: .isInsured)
        try container.encode(insuranceCostYearly, forKey: .insuranceCostYearly)
        try container.encode(icon, forKey: .icon)
    }
}
