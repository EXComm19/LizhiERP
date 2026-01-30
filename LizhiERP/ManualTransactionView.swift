import SwiftUI
import SwiftData

struct ManualTransactionView: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var isPresented: Bool
    
    var transactionToEdit: Transaction?
    
    // Form State
    @State private var inputAmount: Double?
    @State private var selectedType: TransactionType = .expense
    
    // Standard Selection
    @Query(filter: #Predicate<CategoryEntity> { $0.type == "Expense" }, sort: \CategoryEntity.sortOrder) private var expenseCategories: [CategoryEntity]
    @Query(filter: #Predicate<CategoryEntity> { $0.type == "Income" }, sort: \CategoryEntity.sortOrder) private var incomeCategories: [CategoryEntity]
    @State private var selectedCategory: CategoryEntity?
    @State private var selectedSubcategory: String = ""
    
    // Account / Asset Selection
    @Query(filter: #Predicate<AssetEntity> { $0.customID != nil }) private var cashAccounts: [AssetEntity]
    @Query private var allAssets: [AssetEntity]
    
    // Computed property to avoid complex predicate
    var stockAssets: [AssetEntity] {
        allAssets.filter { $0.type == .stock || $0.type == .crypto }
    }
    
    @State private var selectedAccountID: String? = nil // Source
    @State private var destinationAccountID: String? = nil // Dest
    @State private var targetAssetID: UUID? = nil // Stock Target
    @State private var units: Double? // Units Bought
    @State private var pricePerUnit: Double? // Price per share
    @State private var transactionFees: Double? // Brokerage fees
    
    // Common
    @State private var note: String = ""
    @State private var date: Date = Date()
    @State private var showDatePicker = false
    
    // Computed: Auto-calculate total for stock purchases
    var calculatedStockTotal: Double {
        guard let units = units, let pricePerUnit = pricePerUnit else { return 0 }
        let fees = transactionFees ?? 0
        return (pricePerUnit * units) + fees
    }
    @State private var currency: String = CurrencyService.shared.baseCurrency
    
    // Focus
    @FocusState private var isAmountFocused: Bool
    
    // Computed Types
    var currentCategories: [CategoryEntity] {
        switch selectedType {
        case .expense: return expenseCategories
        case .income: return incomeCategories
        default: return []
        }
    }
    
    init(isPresented: Binding<Bool>, transactionToEdit: Transaction? = nil) {
        self._isPresented = isPresented
        self.transactionToEdit = transactionToEdit
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            Color.lizhiBackground.ignoresSafeArea()
            
            VStack(spacing: 24) {
                // 1. Header
                header
                
                // 2. Segmented Picker
                segmentedControl
                
                ScrollView {
                    VStack(spacing: 24) {
                        // 3. Value & Date Row
                        valueDateRow
                        
                        // 4. Dynamic Body
                        if selectedType == .transfer {
                            transferSection
                        } else if selectedType == .assetPurchase {
                            investmentSection
                        } else {
                            standardSection
                        }
                        
                        // 5. Note
                        noteSection
                    }
                    .padding(.bottom, 100)
                }
                
                Spacer()
                
                // 6. Action Button
                saveButton
            }
            .padding(.top, 24)
        }
        .onAppear(perform: loadData)
        .sheet(isPresented: $showDatePicker) {
            DatePicker("Select Date", selection: $date, displayedComponents: [.date])
                .datePickerStyle(.graphical)
                .presentationDetents([.medium])
        }
    }
    
    // MARK: - Sections
    
    var valueDateRow: some View {
        HStack(spacing: 12) {
            HStack {
                Picker("", selection: $currency) {
                    ForEach(CurrencyService.shared.availableCurrencies, id: \.self) { code in
                        Text(CurrencyService.shared.symbol(for: code)).tag(code)
                    }
                }
                .tint(Color.lizhiTextSecondary)
                .labelsHidden()
                
                TextField("0.00", value: $inputAmount, format: .number.precision(.fractionLength(2)))
                    .keyboardType(.decimalPad)
                    .focused($isAmountFocused)
                    .foregroundStyle(Color.lizhiTextPrimary)
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
            }
            .padding()
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.orange.opacity(0.8), lineWidth: 1)
                    .background(Color.lizhiSurface.cornerRadius(12))
            )
            
            Button { showDatePicker = true } label: {
                Text(date.formatted(.dateTime.year().month(.twoDigits).day(.twoDigits)))
                    .font(.system(size: 16, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.lizhiTextPrimary)
                    .padding()
                    .frame(height: 56)
                    .frame(maxWidth: .infinity)
                    .background(Color.lizhiSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .frame(width: 140)
        }
        .padding(.horizontal)
    }
    
    var transferSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Transfer Details")
                .font(.headline)
                .foregroundStyle(Color.lizhiTextPrimary)
                .padding(.horizontal)
            
            // From
            VStack(alignment: .leading, spacing: 8) {
                Text("FROM ACCOUNT")
                    .font(.caption).fontWeight(.bold).foregroundStyle(Color.lizhiTextSecondary)
                    .padding(.horizontal)
                pickerScroll(selection: $selectedAccountID, items: cashAccounts, idKey: \.customID, labelKey: \.ticker)
            }
            
            // To
            VStack(alignment: .leading, spacing: 8) {
                Text("TO ACCOUNT")
                    .font(.caption).fontWeight(.bold).foregroundStyle(Color.lizhiTextSecondary)
                    .padding(.horizontal)
                pickerScroll(selection: $destinationAccountID, items: cashAccounts, idKey: \.customID, labelKey: \.ticker)
            }
        }
    }
    
    var investmentSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Investment Details")
                .font(.headline)
                .foregroundStyle(Color.lizhiTextPrimary)
                .padding(.horizontal)
            
            // From
            VStack(alignment: .leading, spacing: 8) {
                Text("FROM ACCOUNT")
                    .font(.caption).fontWeight(.bold).foregroundStyle(Color.lizhiTextSecondary)
                    .padding(.horizontal)
                pickerScroll(selection: $selectedAccountID, items: cashAccounts, idKey: \.customID, labelKey: \.ticker)
            }
            
            // Target Asset
            VStack(alignment: .leading, spacing: 8) {
                Text("BUY ASSET")
                    .font(.caption).fontWeight(.bold).foregroundStyle(Color.lizhiTextSecondary)
                    .padding(.horizontal)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(stockAssets) { asset in
                            Button {
                                targetAssetID = asset.id
                                triggerHaptic(.glassTap)
                            } label: {
                                Text(asset.ticker)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(targetAssetID == asset.id ? Color.lizhiTextPrimary : Color.lizhiSurface)
                                    .foregroundStyle(targetAssetID == asset.id ? Color.lizhiBackground : Color.lizhiTextSecondary)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            
            // Units
            VStack(alignment: .leading, spacing: 8) {
                Text("QUANTITY")
                    .font(.caption).fontWeight(.bold).foregroundStyle(Color.lizhiTextSecondary)
                    .padding(.horizontal)
                
                TextField("0", value: $units, format: .number)
                    .keyboardType(.decimalPad)
                    .padding()
                    .frame(height: 56)
                    .background(Color.lizhiSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(Color.lizhiTextPrimary)
                    .padding(.horizontal)
            }
            
            // Price Per Unit
            VStack(alignment: .leading, spacing: 8) {
                Text("PRICE PER UNIT")
                    .font(.caption).fontWeight(.bold).foregroundStyle(Color.lizhiTextSecondary)
                    .padding(.horizontal)
                
                TextField("0.00", value: $pricePerUnit, format: .number.precision(.fractionLength(2)))
                    .keyboardType(.decimalPad)
                    .padding()
                    .frame(height: 56)
                    .background(Color.lizhiSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(Color.lizhiTextPrimary)
                    .padding(.horizontal)
            }
            
            // Transaction Fees
            VStack(alignment: .leading, spacing: 8) {
                Text("FEES (OPTIONAL)")
                    .font(.caption).fontWeight(.bold).foregroundStyle(Color.lizhiTextSecondary)
                    .padding(.horizontal)
                
                TextField("0.00", value: $transactionFees, format: .number.precision(.fractionLength(2)))
                    .keyboardType(.decimalPad)
                    .padding()
                    .frame(height: 56)
                    .background(Color.lizhiSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(Color.lizhiTextPrimary)
                    .padding(.horizontal)
            }
            
            // Calculated Total Display
            if units != nil && pricePerUnit != nil {
                VStack(alignment: .leading, spacing: 8) {
                    Text("TOTAL COST")
                        .font(.caption).fontWeight(.bold).foregroundStyle(Color.lizhiTextSecondary)
                        .padding(.horizontal)
                    
                    HStack {
                        Text("$\(calculatedStockTotal.formatted(.number.precision(.fractionLength(2))))")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.blue)
                        
                        Spacer()
                        
                        Text("(\(units?.formatted(.number) ?? "0") × $\(pricePerUnit?.formatted(.number.precision(.fractionLength(2))) ?? "0") + $\((transactionFees ?? 0).formatted(.number.precision(.fractionLength(2)))))")
                            .font(.caption)
                            .foregroundStyle(Color.lizhiTextSecondary)
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                }
            }
        }
    }
    
    var standardSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Category
            VStack(alignment: .leading, spacing: 8) {
                Text("CATEGORY")
                    .font(.caption).fontWeight(.bold).foregroundStyle(Color.lizhiTextSecondary)
                    .padding(.horizontal)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(currentCategories) { cat in
                            categoryItem(cat)
                        }
                        if currentCategories.isEmpty {
                            Text("No categories found. Go to Settings.").font(.caption).foregroundStyle(Color.lizhiTextSecondary).padding(.horizontal)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            
            // Subcategory
            if let category = selectedCategory, !category.subcategories.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("SUBCATEGORY")
                        .font(.caption).fontWeight(.bold).foregroundStyle(Color.lizhiTextSecondary)
                        .padding(.horizontal)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(category.subcategories, id: \.self) { sub in
                                subcategoryItem(sub)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            
            // Account Optional
            VStack(alignment: .leading, spacing: 8) {
                Text("ACCOUNT (OPTIONAL)")
                    .font(.caption).fontWeight(.bold).foregroundStyle(Color.lizhiTextSecondary)
                    .padding(.horizontal)
                pickerScroll(selection: $selectedAccountID, items: cashAccounts, idKey: \.customID, labelKey: \.ticker)
            }
        }
    }
    
    var noteSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("NOTE")
                .font(.caption).fontWeight(.bold).foregroundStyle(Color.lizhiTextSecondary)
                .padding(.horizontal)
            
            TextField("Description", text: $note)
                .padding()
                .frame(height: 56)
                .background(Color.lizhiSurface)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .foregroundStyle(Color.lizhiTextPrimary)
                .padding(.horizontal)
        }
    }
    
    var saveButton: some View {
        Button(action: saveTransaction) {
            Text(transactionToEdit == nil ? "Add Record" : "Update Record")
                .font(.headline)
                .foregroundStyle(Color.lizhiBackground)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Color.lizhiTextPrimary)
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .padding(.horizontal)
        .padding(.bottom, 40)
    }
    
    // MARK: - Helpers
    
    func pickerScroll<T: Identifiable>(selection: Binding<String?>, items: [T], idKey: KeyPath<T, String?>, labelKey: KeyPath<T, String>) -> some View {
         ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                Button {
                    selection.wrappedValue = nil
                    triggerHaptic(.glassTap)
                } label: {
                    Text("None")
                        .font(.caption).fontWeight(.medium)
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .background(selection.wrappedValue == nil ? Color.lizhiTextPrimary : Color.lizhiSurface)
                        .foregroundStyle(selection.wrappedValue == nil ? Color.lizhiBackground : Color.lizhiTextSecondary)
                        .clipShape(Capsule())
                }
                
                ForEach(items) { item in
                    if let id = item[keyPath: idKey] {
                        Button {
                            selection.wrappedValue = id
                            triggerHaptic(.glassTap)
                        } label: {
                            Text(item[keyPath: labelKey])
                                .font(.caption).fontWeight(.medium)
                                .padding(.horizontal, 16).padding(.vertical, 8)
                                .background(selection.wrappedValue == id ? Color.lizhiTextPrimary : Color.lizhiSurface)
                                .foregroundStyle(selection.wrappedValue == id ? Color.lizhiBackground : Color.lizhiTextSecondary)
                                .clipShape(Capsule())
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
    }
    
    var segmentedControl: some View {
        HStack(spacing: 0) {
            segmentButton("Expense", .expense)
            Divider().background(Color.lizhiTextPrimary.opacity(0.1))
            segmentButton("Income", .income)
            Divider().background(Color.lizhiTextPrimary.opacity(0.1))
            segmentButton("Transfer", .transfer)
            Divider().background(Color.lizhiTextPrimary.opacity(0.1))
            segmentButton("Invest", .assetPurchase)
        }
        .frame(height: 44)
        .background(Color.lizhiSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }
    
    func segmentButton(_ title: String, _ type: TransactionType) -> some View {
        Button {
            withAnimation(.spring()) { selectedType = type }
            triggerHaptic(.glassTap)
        } label: {
            Text(title)
                .font(.system(size: 13, weight: .medium)) // Slightly smaller for 4 items
                .foregroundStyle(selectedType == type ? Color.lizhiTextPrimary : Color.lizhiTextSecondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(selectedType == type ? Color.lizhiSurface.opacity(0.5) : Color.clear)
        }
    }
    
    func categoryItem(_ cat: CategoryEntity) -> some View {
        Button {
            selectedCategory = cat
            selectedSubcategory = cat.subcategories.first ?? ""
            triggerHaptic(.glassTap)
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(selectedCategory?.persistentModelID == cat.persistentModelID ? Color.blue.opacity(0.2) : Color.lizhiSurface)
                        .frame(width: 48, height: 48)
                    Image(systemName: cat.icon)
                        .font(.body)
                        .foregroundStyle(selectedCategory?.persistentModelID == cat.persistentModelID ? .blue : Color.lizhiTextSecondary)
                }
                .overlay(
                    Circle().stroke(selectedCategory?.persistentModelID == cat.persistentModelID ? Color.lizhiTextSecondary.opacity(0.5) : Color.clear, lineWidth: 1)
                )
                Text(cat.name).font(.caption2).foregroundStyle(Color.lizhiTextPrimary)
            }
        }
    }
    
    func subcategoryItem(_ name: String) -> some View {
        Button {
            selectedSubcategory = name
            triggerHaptic(.glassTap)
        } label: {
            Text(name)
                .font(.caption).fontWeight(.medium)
                .padding(.horizontal, 16).padding(.vertical, 8)
                .background(selectedSubcategory == name ? Color.lizhiTextPrimary : Color.lizhiSurface)
                .foregroundStyle(selectedSubcategory == name ? Color.lizhiBackground : Color.lizhiTextSecondary)
                .clipShape(Capsule())
        }
    }
    
    var header: some View {
        HStack {
            Text(transactionToEdit == nil ? "New Record" : "Edit Record")
                .font(.title2).fontWeight(.bold).foregroundStyle(Color.lizhiTextPrimary)
            Spacer()
            Button { isPresented = false } label: {
                Image(systemName: "xmark")
                    .font(.subheadline).fontWeight(.bold).foregroundStyle(Color.lizhiTextSecondary)
                    .padding(8).background(Color.lizhiSurface).clipShape(Circle())
            }
        }
        .padding(.horizontal).padding(.top, 20)
    }
    
    // MARK: - Load & Save
    
    func loadData() {
        if let tx = transactionToEdit {
            inputAmount = NSDecimalNumber(decimal: tx.amount).doubleValue
            selectedType = tx.type
            date = tx.date
            selectedSubcategory = tx.subcategory
            currency = tx.currency
            note = tx.contextTags.first ?? ""
            selectedAccountID = tx.linkedAccountID
            destinationAccountID = tx.destinationAccountID
            targetAssetID = tx.targetAssetID
            units = tx.units != nil ? NSDecimalNumber(decimal: tx.units!).doubleValue : nil
            
            // Match Category
            let list = (tx.type == .expense ? expenseCategories : incomeCategories)
            if let match = list.first(where: { $0.subcategories.contains(tx.subcategory) }) {
                 selectedCategory = match
            }
            
            // Load price per unit and fees from linked StockTransaction (for asset purchases)
            if tx.type == .assetPurchase {
                let txID = tx.id
                let stockDescriptor = FetchDescriptor<StockTransaction>(predicate: #Predicate { $0.transactionID == txID })
                if let stockTx = try? modelContext.fetch(stockDescriptor).first {
                    pricePerUnit = NSDecimalNumber(decimal: stockTx.pricePerUnit).doubleValue
                    transactionFees = NSDecimalNumber(decimal: stockTx.fees).doubleValue
                    print("📊 Loaded StockTransaction: units=\(stockTx.units), price=\(stockTx.pricePerUnit), fees=\(stockTx.fees)")
                } else {
                    print("⚠️ No linked StockTransaction found for transaction ID: \(tx.id)")
                }
            }
        } else {
            isAmountFocused = true
            if let first = currentCategories.first {
                selectedCategory = first
                selectedSubcategory = first.subcategories.first ?? ""
            }
        }
    }
    
    func saveTransaction() {
        // For stock purchases, use calculated total instead of manual input
        let finalAmount: Double
        if selectedType == .assetPurchase && pricePerUnit != nil && units != nil {
            finalAmount = calculatedStockTotal
        } else {
            guard let amount = inputAmount, amount > 0 else { return }
            finalAmount = amount
        }
        
        let mappedCat = selectedCategory?.mappedCategory ?? ((selectedType == .transfer || selectedType == .assetPurchase) ? .uncategorized : .survival)
        let catName = selectedCategory?.name ?? ""
        
        var tags: [String] = []
        if !note.isEmpty { tags.append(note) }
        
        // Polymorphic Unit Handling
        let finalUnits: Decimal? = (selectedType == .assetPurchase && units != nil) ? Decimal(units!) : nil
        
        // Track the transaction ID for linking to StockTransaction
        var txID: UUID
        
        if let tx = transactionToEdit {
            tx.amount = Decimal(finalAmount)
            tx.type = selectedType
            tx.category = mappedCat
            tx.date = date
            tx.categoryName = catName
            tx.subcategory = selectedSubcategory
            tx.contextTags = tags
            tx.currency = currency
            tx.linkedAccountID = selectedAccountID
            tx.destinationAccountID = destinationAccountID
            tx.targetAssetID = targetAssetID
            tx.units = finalUnits
            txID = tx.id
        } else {
            let newTx = Transaction(
                amount: Decimal(finalAmount),
                type: selectedType,
                category: mappedCat,
                source: .spending,
                date: date,
                contextTags: tags,
                categoryName: catName,
                subcategory: selectedSubcategory,
                linkedAccountID: selectedAccountID,
                currency: currency,
                destinationAccountID: destinationAccountID,
                targetAssetID: targetAssetID,
                units: finalUnits
            )
            modelContext.insert(newTx)
            txID = newTx.id
        }
        
        try? modelContext.save()
        
        // Record stock transaction if this is a stock purchase
        if selectedType == .assetPurchase,
           let assetID = targetAssetID,
           let units = units,
           let price = pricePerUnit {
            
            // Check if a StockTransaction already exists for this transaction
            let targetTxID = txID
            let existingDescriptor = FetchDescriptor<StockTransaction>(predicate: #Predicate { $0.transactionID == targetTxID })
            let existingStockTx = try? modelContext.fetch(existingDescriptor).first
            
            // Get old values before update (for adjusting asset totals)
            let oldUnits = existingStockTx?.units ?? 0
            let oldTotalAmount = existingStockTx?.totalAmount ?? 0
            
            if let stockTx = existingStockTx {
                // Update existing stock transaction
                stockTx.units = Decimal(units)
                stockTx.pricePerUnit = Decimal(price)
                stockTx.fees = Decimal(transactionFees ?? 0)
                stockTx.date = date
                stockTx.notes = note
            } else {
                // Create new StockTransaction linked to the transaction
                let stockTx = StockTransaction(
                    assetID: assetID,
                    transactionID: txID,
                    type: .buy,
                    units: Decimal(units),
                    pricePerUnit: Decimal(price),
                    fees: Decimal(transactionFees ?? 0),
                    date: date,
                    notes: note
                )
                modelContext.insert(stockTx)
            }
            
            // Update asset holdings and market value
            let descriptor = FetchDescriptor<AssetEntity>(predicate: #Predicate { $0.id == assetID })
            if let asset = try? modelContext.fetch(descriptor).first {
                // Adjust holdings: remove old, add new
                asset.holdings = asset.holdings - oldUnits + Decimal(units)
                asset.marketValue = Decimal(price) // Update to latest buy price
                asset.lastUpdated = date
                
                // Adjust total invested: remove old amount, add new
                let newPurchaseAmount = (Decimal(price) * Decimal(units)) + Decimal(transactionFees ?? 0)
                asset.initialValue = (asset.initialValue ?? 0) - oldTotalAmount + newPurchaseAmount
            }
            
            try? modelContext.save()
            
            // Recalculate balances in background
            let container = modelContext.container
            Task {
                let engine = FinancialEngine(modelContainer: container)
                await engine.recalculateAssetBalances()
            }
        } else {
            // For non-stock transactions, just recalculate balances
            let container = modelContext.container
            Task {
                let engine = FinancialEngine(modelContainer: container)
                await engine.recalculateAssetBalances()
            }
        }
        
        triggerHaptic(.hustle)
        isPresented = false
    }
}
