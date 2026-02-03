import Foundation
import SwiftData

@Model
final class Subscription {
    var id: UUID
    var name: String
    var amount: Decimal
    var cycle: String // "Monthly", "Yearly", "Weekly"
    var isActive: Bool
    var notes: String
    var paymentMethod: String // "Card", "PayPal"
    var currency: String = "AUD"
    
    // Transaction-aligned category fields (stored as raw strings for SwiftData compatibility)
    var typeRaw: String = "Expense"  // "Expense" or "Income"
    var categoryRaw: String = "survival"  // engine category raw value
    var categoryName: String = "Bills"  // user-facing category
    var subcategory: String = "Subscription"  // subcategory
    var linkedAccountID: String?  // payment source account
    
    // Legacy field - kept for backwards compatibility, will be removed in future
    var icon: String = "tv"
    var weekdaysOnly: Bool = false
    
    // NEW: Optional domain for Logo.dev fetch
    var brandDomain: String?
    
    // NEW: Separating the "Anchor" start date from the "Runner" next date
    var initialBillDate: Date = Date()
    
    @Attribute(originalName: "firstBillDate")
    var nextPaymentDate: Date
    
    // Computed accessors for type-safe enum access
    var type: TransactionType {
        get { TransactionType(rawValue: typeRaw) ?? .expense }
        set { typeRaw = newValue.rawValue }
    }
    
    var category: TransactionCategory {
        get { TransactionCategory(rawValue: categoryRaw) ?? .survival }
        set { categoryRaw = newValue.rawValue }
    }
    
    init(
        name: String,
        amount: Decimal,
        cycle: String = "Monthly",
        firstBillDate: Date = Date(), // This argument now treats as "Start Date"
        isActive: Bool = true,
        notes: String = "",
        paymentMethod: String = "Card",
        currency: String = "AUD",
        type: TransactionType = .expense,
        category: TransactionCategory = .survival,
        categoryName: String = "Bills",
        subcategory: String = "Subscription",
        linkedAccountID: String? = nil,
        icon: String = "tv",
        weekdaysOnly: Bool = false,
        brandDomain: String? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.amount = amount
        self.cycle = cycle
        self.initialBillDate = firstBillDate
        self.nextPaymentDate = firstBillDate // Initialize runner to start date
        self.isActive = isActive
        self.notes = notes
        self.paymentMethod = paymentMethod
        self.currency = currency
        self.typeRaw = type.rawValue
        self.categoryRaw = category.rawValue
        self.categoryName = categoryName
        self.subcategory = subcategory
        self.linkedAccountID = linkedAccountID
        self.icon = icon
        self.weekdaysOnly = weekdaysOnly
        self.brandDomain = brandDomain
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
            nextPaymentDate = calendar.date(byAdding: .day, value: 7, to: nextPaymentDate) ?? nextPaymentDate
        case "Yearly":
            nextPaymentDate = calendar.date(byAdding: .year, value: 1, to: nextPaymentDate) ?? nextPaymentDate
        default: // Monthly
            nextPaymentDate = calendar.date(byAdding: .month, value: 1, to: nextPaymentDate) ?? nextPaymentDate
        }
        
        // If weekdays only, ensure we don't land on a weekend
        if weekdaysOnly {
            while calendar.isDateInWeekend(nextPaymentDate) {
                nextPaymentDate = calendar.date(byAdding: .day, value: 1, to: nextPaymentDate) ?? nextPaymentDate
            }
        }
    }
    
    // Calculated property for display: The next effective bill date relative to now
    var effectiveNextDate: Date {
        let today = Date()
        var date = nextPaymentDate
        let calendar = Calendar.current
        
        // If nextPaymentDate is already in the future, that's the next one
        if date > today {
            // Check weekend constraint
            if weekdaysOnly {
                var checkedDate = date
                while calendar.isDateInWeekend(checkedDate) {
                    checkedDate = calendar.date(byAdding: .day, value: 1, to: checkedDate) ?? checkedDate
                }
                return checkedDate
            }
            return date
        }
        
        // Calculate intervals to jump ahead
        switch cycle {
        case "Weekly":
            let daysBetween = calendar.dateComponents([.day], from: date, to: today).day ?? 0
            let weeks = (daysBetween / 7) + 1
            date = calendar.date(byAdding: .day, value: weeks * 7, to: date) ?? date
            
        case "Yearly":
            let yearsBetween = calendar.dateComponents([.year], from: date, to: today).year ?? 0
            let yearsToAdd = yearsBetween + 1
            date = calendar.date(byAdding: .year, value: yearsToAdd, to: date) ?? date
            
        default: // Monthly
            let monthsBetween = calendar.dateComponents([.month], from: date, to: today).month ?? 0
            let monthsToAdd = monthsBetween + 1
            date = calendar.date(byAdding: .month, value: monthsToAdd, to: date) ?? date
        }
        
        // Safety check: ensure it is > today
        while date <= today {
            switch cycle {
            case "Weekly":
                date = calendar.date(byAdding: .day, value: 7, to: date) ?? date
            case "Yearly":
                date = calendar.date(byAdding: .year, value: 1, to: date) ?? date
            default:
                date = calendar.date(byAdding: .month, value: 1, to: date) ?? date
            }
        }
        
        // Apply weekend check
        if weekdaysOnly {
            while calendar.isDateInWeekend(date) {
                date = calendar.date(byAdding: .day, value: 1, to: date) ?? date
            }
        }
        
        return date
    }
}
