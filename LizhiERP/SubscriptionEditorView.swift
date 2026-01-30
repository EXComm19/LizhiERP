import SwiftUI
import SwiftData

struct SubscriptionEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var isPresented: Bool
    
    var subscriptionToEdit: Subscription? // Optional binding if passed
    
    // Form State
    @State private var name: String = ""
    @State private var amount: Double?
    @State private var selectedCycle: String = "Monthly"
    @State private var firstBillDate: Date = Date()
    @State private var currency: String = CurrencyService.shared.baseCurrency
    
    // NEW: Type and Category selection (matching Transaction system)
    @State private var selectedType: TransactionType = .expense
    @Query(filter: #Predicate<CategoryEntity> { $0.type == "Expense" }, sort: \CategoryEntity.sortOrder) private var expenseCategories: [CategoryEntity]
    @Query(filter: #Predicate<CategoryEntity> { $0.type == "Income" }, sort: \CategoryEntity.sortOrder) private var incomeCategories: [CategoryEntity]
    @State private var selectedCategory: CategoryEntity?
    @State private var selectedSubcategory: String = ""
    
    // Account Selection
    @Query(filter: #Predicate<AssetEntity> { $0.customID != nil }) private var cashAccounts: [AssetEntity]
    @State private var selectedAccountID: String? = nil
    
    @State private var showDatePicker = false
    @State private var weekdaysOnly = false
    
    @FocusState private var isNameFocused: Bool
    
    var currentCategories: [CategoryEntity] {
        switch selectedType {
        case .expense: return expenseCategories
        case .income: return incomeCategories
        default: return []
        }
    }
    
    init(isPresented: Binding<Bool>, subscriptionToEdit: Subscription? = nil) {
        self._isPresented = isPresented
        self.subscriptionToEdit = subscriptionToEdit
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            Color.lizhiBackground.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    HStack {
                        Text(subscriptionToEdit == nil ? "New Recurring" : "Edit Recurring")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.lizhiTextPrimary)
                        Spacer()
                        Button {
                            isPresented = false
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundStyle(Color.lizhiTextSecondary)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Type Toggle (Expense vs Income)
                    typeToggleSection
                    
                    // Name Input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("NAME")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.lizhiTextSecondary)
                        
                        TextField("e.g. Netflix, Salary", text: $name)
                            .padding()
                            .frame(height: 50)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.blue, lineWidth: 1)
                                    .background(Color.lizhiSurface.cornerRadius(12))
                            )
                            .foregroundStyle(Color.lizhiTextPrimary)
                            .focused($isNameFocused)
                    }
                    .padding(.horizontal)
                    
                    // Category Selection
                    categorySection
                    
                    // Subcategory Selection
                    if let cat = selectedCategory, !cat.subcategories.isEmpty {
                        subcategorySection(cat)
                    }
                    
                    // Amount & Cycle
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("AMOUNT")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundStyle(Color.lizhiTextSecondary)
                            
                            HStack {
                                // Currency Picker
                                Picker("", selection: $currency) {
                                    ForEach(CurrencyService.shared.availableCurrencies, id: \.self) { code in
                                        Text(CurrencyService.shared.symbol(for: code)).tag(code)
                                    }
                                }
                                .tint(Color.lizhiTextSecondary)
                                .labelsHidden()
                                
                                TextField("0.00", value: $amount, format: .number.precision(.fractionLength(2)))
                                    .keyboardType(.decimalPad)
                                    .foregroundStyle(Color.lizhiTextPrimary)
                            }
                            .padding()
                            .frame(height: 56)
                            .background(Color.lizhiSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("CYCLE")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundStyle(Color.lizhiTextSecondary)
                            
                            Menu {
                                Button("Monthly") { selectedCycle = "Monthly" }
                                Button("Yearly") { selectedCycle = "Yearly" }
                                Button("Weekly") { selectedCycle = "Weekly" }
                            } label: {
                                HStack {
                                    Text(selectedCycle)
                                        .foregroundStyle(Color.lizhiTextPrimary)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                    Spacer()
                                    Image(systemName: "chevron.up.chevron.down")
                                        .foregroundStyle(Color.lizhiTextSecondary)
                                }
                                .padding()
                                .frame(height: 56)
                                .background(Color.lizhiSurface)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    // Account Selection (optional)
                    accountSection
                    
                    // First Bill Date
                    VStack(alignment: .leading, spacing: 8) {
                        Text("FIRST BILL DATE")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.lizhiTextSecondary)
                        
                        HStack(spacing: 12) {
                            Button {
                                showDatePicker = true
                            } label: {
                                HStack {
                                    Text(firstBillDate.formatted(date: .numeric, time: .omitted))
                                        .foregroundStyle(Color.lizhiTextPrimary)
                                    Spacer()
                                    Image(systemName: "calendar")
                                        .foregroundStyle(Color.lizhiTextSecondary)
                                }
                                .padding()
                                .frame(height: 56)
                                .background(Color.lizhiSurface)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            
                            Button {
                                weekdaysOnly.toggle()
                                triggerHaptic(.glassTap)
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: weekdaysOnly ? "checkmark.square.fill" : "square")
                                        .foregroundStyle(weekdaysOnly ? Color.blue : Color.lizhiTextSecondary)
                                    Text("Weekdays\nOnly")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundStyle(Color.lizhiTextPrimary)
                                        .lineLimit(2)
                                        .minimumScaleFactor(0.8)
                                }
                                .padding(.horizontal, 12)
                                .frame(height: 56)
                                .background(Color.lizhiSurface)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                        
                        // Read Only Next Bill Display
                        if let sub = subscriptionToEdit {
                            Text("Next Bill Due: \(sub.effectiveNextDate.formatted(date: .long, time: .omitted))")
                                .font(.caption)
                                .foregroundStyle(Color.lizhiTextSecondary)
                                .padding(.top, 4)
                        }
                    }
                    .padding(.horizontal)
                    
                    Spacer().frame(height: 100)
                }
                .padding(.top, 24)
            }
            
            // Create Button
            VStack {
                Spacer()
                Button(action: saveSubscription) {
                    Text(subscriptionToEdit == nil ? "Create Recurring" : "Update Recurring")
                        .font(.headline)
                        .foregroundStyle(Color.lizhiBackground)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.lizhiTextPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
        }
        .onAppear {
            if let sub = subscriptionToEdit {
                name = sub.name
                amount = NSDecimalNumber(decimal: sub.amount).doubleValue
                selectedCycle = sub.cycle
                firstBillDate = sub.initialBillDate 
                currency = sub.currency
                selectedType = sub.type
                selectedSubcategory = sub.subcategory
                selectedAccountID = sub.linkedAccountID
                
                // Find matching category
                let cats = sub.type == .income ? incomeCategories : expenseCategories
                selectedCategory = cats.first(where: { $0.name == sub.categoryName })
                weekdaysOnly = sub.weekdaysOnly
            } else {
                isNameFocused = true
                // Default to first category
                if let first = expenseCategories.first {
                    selectedCategory = first
                }
            }
        }
        .sheet(isPresented: $showDatePicker) {
            DatePicker("Select Date", selection: $firstBillDate, displayedComponents: [.date])
                .datePickerStyle(.graphical)
                .presentationDetents([.medium])
        }
        .onChange(of: selectedType) { _, _ in
            // Reset category when type changes
            selectedCategory = currentCategories.first
            selectedSubcategory = ""
        }
    }
    
    // MARK: - Type Toggle
    var typeToggleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TYPE")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(Color.lizhiTextSecondary)
                .padding(.horizontal)
            
            HStack(spacing: 12) {
                Button {
                    selectedType = .expense
                    triggerHaptic(.glassTap)
                } label: {
                    HStack {
                        Image(systemName: "arrow.down.circle.fill")
                        Text("Expense")
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(selectedType == .expense ? Color.orange : Color.lizhiSurface)
                    .foregroundStyle(selectedType == .expense ? Color.white : Color.lizhiTextSecondary)
                    .clipShape(Capsule())
                }
                
                Button {
                    selectedType = .income
                    triggerHaptic(.glassTap)
                } label: {
                    HStack {
                        Image(systemName: "arrow.up.circle.fill")
                        Text("Income")
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(selectedType == .income ? Color.green : Color.lizhiSurface)
                    .foregroundStyle(selectedType == .income ? Color.white : Color.lizhiTextSecondary)
                    .clipShape(Capsule())
                }
                
                Spacer()
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - Category Section
    var categorySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("CATEGORY")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(Color.lizhiTextSecondary)
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(currentCategories, id: \.name) { cat in
                        Button {
                            selectedCategory = cat
                            selectedSubcategory = cat.subcategories.first ?? ""
                            triggerHaptic(.glassTap)
                        } label: {
                            VStack(spacing: 6) {
                                Image(systemName: cat.icon)
                                    .font(.title3)
                                Text(cat.name)
                                    .font(.caption2)
                                    .lineLimit(1)
                            }
                            .frame(width: 70, height: 60)
                            .background(selectedCategory?.name == cat.name ? Color.lizhiTextPrimary : Color.lizhiSurface)
                            .foregroundStyle(selectedCategory?.name == cat.name ? Color.lizhiBackground : Color.lizhiTextSecondary)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    // MARK: - Subcategory Section
    func subcategorySection(_ cat: CategoryEntity) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SUBCATEGORY")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(Color.lizhiTextSecondary)
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(cat.subcategories, id: \.self) { sub in
                        Button {
                            selectedSubcategory = sub
                            triggerHaptic(.glassTap)
                        } label: {
                            Text(sub)
                                .font(.caption)
                                .fontWeight(.medium)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(selectedSubcategory == sub ? Color.lizhiTextPrimary : Color.lizhiSurface)
                                .foregroundStyle(selectedSubcategory == sub ? Color.lizhiBackground : Color.lizhiTextSecondary)
                                .clipShape(Capsule())
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    // MARK: - Account Section
    var accountSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("PAYMENT ACCOUNT (OPTIONAL)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(Color.lizhiTextSecondary)
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    // None option
                    Button {
                        selectedAccountID = nil
                        triggerHaptic(.glassTap)
                    } label: {
                        Text("None")
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(selectedAccountID == nil ? Color.lizhiTextPrimary : Color.lizhiSurface)
                            .foregroundStyle(selectedAccountID == nil ? Color.lizhiBackground : Color.lizhiTextSecondary)
                            .clipShape(Capsule())
                    }
                    
                    ForEach(cashAccounts, id: \.id) { account in
                        Button {
                            selectedAccountID = account.customID
                            triggerHaptic(.glassTap)
                        } label: {
                            Text(account.ticker)
                                .font(.caption)
                                .fontWeight(.medium)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(selectedAccountID == account.customID ? Color.lizhiTextPrimary : Color.lizhiSurface)
                                .foregroundStyle(selectedAccountID == account.customID ? Color.lizhiBackground : Color.lizhiTextSecondary)
                                .clipShape(Capsule())
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    func saveSubscription() {
        print("DEBUG: Attempting to save subscription. Name: \(name), Amount: \(String(describing: amount))")
        
        guard let amount = amount, !name.isEmpty else {
            print("DEBUG: Validation failed. Name empty or Amount nil")
            return
        }
        
        // Get category mappings
        let categoryName = selectedCategory?.name ?? "Bills"
        let engineCategory = selectedCategory?.mappedCategory ?? .survival
        let subcategory = selectedSubcategory.isEmpty ? (selectedCategory?.subcategories.first ?? "General") : selectedSubcategory
        
        if let sub = subscriptionToEdit {
            // Update existing
            sub.name = name
            sub.amount = Decimal(amount)
            sub.cycle = selectedCycle
            sub.initialBillDate = firstBillDate
            sub.nextPaymentDate = firstBillDate // Reset runner to new start date
            sub.currency = currency
            sub.type = selectedType
            sub.category = engineCategory
            sub.categoryName = categoryName
            sub.subcategory = subcategory
            sub.linkedAccountID = selectedAccountID
            sub.weekdaysOnly = weekdaysOnly
            print("DEBUG: Updating existing subscription: \(sub.name)")
        } else {
            // Create new
            let sub = Subscription(
                name: name,
                amount: Decimal(amount),
                cycle: selectedCycle,
                firstBillDate: firstBillDate,
                currency: currency,
                type: selectedType,
                category: engineCategory,
                categoryName: categoryName,
                subcategory: subcategory,
                linkedAccountID: selectedAccountID,
                weekdaysOnly: weekdaysOnly
            )
            modelContext.insert(sub)
            print("DEBUG: Inserting new subscription: \(sub.name)")
        }
        
        do {
            try modelContext.save()
            print("DEBUG: Context saved successfully")
        } catch {
            print("DEBUG: Context save failed: \(error)")
        }
        
        triggerHaptic(.hustle)
        isPresented = false
    }
}
