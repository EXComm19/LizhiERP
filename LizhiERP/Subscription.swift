import Foundation
import SwiftData

@Model
final class Subscription {
    var id: UUID
    var name: String
    var amount: Decimal
    var cycle: String // "Monthly", "Yearly", "Weekly"
    var firstBillDate: Date
    var icon: String
    var isActive: Bool
    var notes: String
    var paymentMethod: String // "Card", "PayPal"
    
    init(name: String, amount: Decimal, cycle: String = "Monthly", firstBillDate: Date = Date(), icon: String = "tv", isActive: Bool = true, notes: String = "", paymentMethod: String = "Card") {
        self.id = UUID()
        self.name = name
        self.amount = amount
        self.cycle = cycle
        self.firstBillDate = firstBillDate
        self.icon = icon
        self.isActive = isActive
        self.notes = notes
        self.paymentMethod = paymentMethod
    }
    
    // Logic to calculate monthly equivalent cost
    var monthlyCost: Decimal {
        switch cycle {
        case "Weekly": return amount * 4
        case "Yearly": return amount / 12
        default: return amount
        }
    }
    
    func advanceDueDate() {
        let calendar = Calendar.current
        switch cycle {
        case "Weekly":
            firstBillDate = calendar.date(byAdding: .day, value: 7, to: firstBillDate) ?? firstBillDate
        case "Yearly":
            firstBillDate = calendar.date(byAdding: .year, value: 1, to: firstBillDate) ?? firstBillDate
        default: // Monthly
            firstBillDate = calendar.date(byAdding: .month, value: 1, to: firstBillDate) ?? firstBillDate
        }
    }
}
