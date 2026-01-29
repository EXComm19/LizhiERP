import SwiftUI
import SwiftData

struct VaultView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \AssetEntity.lastUpdated, order: .reverse) private var assets: [AssetEntity]
    
    // Editor State
    @State private var showAssetEditor: Bool = false
    @State private var selectedAsset: AssetEntity? = nil
    
    // Derived - Convert all values to base currency before summing
    var totalNetWorth: Decimal {
        assets.reduce(0) { total, asset in
            total + CurrencyService.shared.convertToBase(asset.totalValue, from: asset.currency)
        }
    }
    
    var cashAssets: [AssetEntity] {
        assets.filter { $0.type == .cash }
    }
    
    var stockAssets: [AssetEntity] {
        assets.filter { $0.type == .stock || $0.type == .crypto }
    }
    
    var otherAssets: [AssetEntity] {
        assets.filter { $0.type == .other }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header: Large Bold Title + Subtitle (Left Aligned)
            VStack(alignment: .leading, spacing: 4) {
                Text("Assets")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.lizhiTextPrimary)
                
                Text("Total: \(CurrencyService.shared.symbol(for: CurrencyService.shared.baseCurrency))\(Int(NSDecimalNumber(decimal: totalNetWorth).doubleValue).formattedWithSeparator)")
                    .font(.subheadline)
                    .foregroundStyle(Color.lizhiTextSecondary)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 20)
            
            // Content List - Using List for swipe actions
            List {
                // CASH SECTION
                if !cashAssets.isEmpty {
                    Section {
                        ForEach(cashAssets) { asset in
                            VaultAssetRow(asset: asset, icon: "wallet.pass.fill", iconColor: .blue)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedAsset = asset
                                    showAssetEditor = true
                                    triggerHaptic(.glassTap)
                                }
                                .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        deleteAsset(asset)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    } header: {
                        Text("CASH")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.lizhiTextSecondary)
                            .kerning(1.2)
                    }
                    .listSectionSeparator(.hidden)
                }
                
                // STOCK SECTION
                if !stockAssets.isEmpty {
                    Section {
                        ForEach(stockAssets) { asset in
                            VaultAssetRow(asset: asset, icon: "chart.line.uptrend.xyaxis", iconColor: .green)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedAsset = asset
                                    showAssetEditor = true
                                    triggerHaptic(.glassTap)
                                }
                                .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        deleteAsset(asset)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    } header: {
                        Text("STOCK")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.lizhiTextSecondary)
                            .kerning(1.2)
                    }
                    .listSectionSeparator(.hidden)
                }
                
                // OTHER SECTION
                if !otherAssets.isEmpty {
                    Section {
                        ForEach(otherAssets) { asset in
                            VaultAssetRow(asset: asset, icon: "cube.box.fill", iconColor: .purple)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedAsset = asset
                                    showAssetEditor = true
                                    triggerHaptic(.glassTap)
                                }
                                .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        deleteAsset(asset)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    } header: {
                        Text("OTHER")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.lizhiTextSecondary)
                            .kerning(1.2)
                    }
                    .listSectionSeparator(.hidden)
                }
                
                // Bottom Padding
                Section {
                    Spacer().frame(height: 100)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
        .background(Color.lizhiBackground.ignoresSafeArea())
        .sheet(isPresented: $showAssetEditor) {
            VaultAssetEditor(isPresented: $showAssetEditor, assetToEdit: selectedAsset)
        }
        .onChange(of: showAssetEditor) { _, newValue in
            if !newValue {
                selectedAsset = nil // Clear selection when sheet closes
            }
        }
    }
    
    func deleteAsset(_ asset: AssetEntity) {
        modelContext.delete(asset)
        triggerHaptic(.glassTap)
    }
}

// MARK: - Components

struct VaultAssetRow: View {
    let asset: AssetEntity
    let icon: String
    let iconColor: Color
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            Circle()
                .fill(Color.lizhiSurface) // Darker inner bg
                .frame(width: 48, height: 48)
                .overlay(
                    Image(systemName: icon)
                        .foregroundStyle(iconColor)
                        .font(.title3)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(asset.ticker)
                        .font(.headline)
                        .foregroundStyle(Color.lizhiTextPrimary)
                    
                    if let code = asset.customID {
                        Text(code)
                            .font(.caption2)
                            .fontWeight(.bold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.lizhiTextSecondary.opacity(0.1))
                            .foregroundStyle(Color.lizhiTextSecondary)
                            .clipShape(Capsule())
                    }
                }
                
                // Subtitle: e.g. "12500 AUD" or "150 IVV"
                if asset.type == .cash {
                     Text(asset.customID ?? asset.currency)
                        .font(.caption)
                        .foregroundStyle(Color.lizhiTextSecondary)
                } else {
                    Text("\(asset.holdings.formatted()) \(asset.currency.isEmpty ? "Units" : asset.currency)")
                        .font(.caption)
                        .foregroundStyle(Color.lizhiTextSecondary)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                // Show raw value here or converted?
                // Usually Vault shows the raw value I have.
                // Dashboard shows the Net Worth.
                Text("$\(Int(NSDecimalNumber(decimal: asset.totalValue).doubleValue).formattedWithSeparator)")
                    .font(.headline) // Make it bold/prominent
                    .fontWeight(.bold)
                    .foregroundStyle(Color.lizhiTextPrimary)
                
                // For stocks, ideally show change %. We don't have this in data yet.
                // Placeholder logic:
                if asset.type == .stock {
                    Text("+1.2%") // Mock
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.green)
                }
            }
        }
        .padding()
        .background(Color.lizhiSurface) // Dark Card
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.lizhiTextSecondary.opacity(0.1), lineWidth: 1))
    }
}

// MARK: - Editor

struct VaultAssetEditor: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var isPresented: Bool
    var assetToEdit: AssetEntity? = nil
    
    @State private var name: String = "" // Ticker/Name
    @State private var holdings: Double?
    @State private var value: Double? // Market Value / Balance
    @State private var type: AssetType = .cash
    @State private var currency: String = CurrencyService.shared.baseCurrency
    
    // Bank Account Features
    @State private var customID: String = ""
    @State private var initialBalance: Double?
    
    var isEditing: Bool { assetToEdit != nil }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Type") {
                    Picker("Asset Type", selection: $type) {
                        ForEach(AssetType.allCases, id: \.self) { t in
                            Text(t.rawValue).tag(t)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                Section("Details") {
                    TextField("Name (e.g. CommBank, IVV)", text: $name)
                    
                    if type == .cash {
                        TextField("Account ID (e.g. CBA, AMEX)", text: $customID)
                            .textInputAutocapitalization(.characters)
                        
                        TextField("Initial Balance", value: $initialBalance, format: .number)
                            .keyboardType(.decimalPad)
                            
                        // Current Balance (Computed/Updated via Transactions, but editable override)
                        LabeledContent("Current Balance") {
                             TextField("Current Balance", value: $value, format: .number)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                        }
                    } else {
                        TextField("Units Held", value: $holdings, format: .number)
                            .keyboardType(.decimalPad)
                        TextField("Price per Unit", value: $value, format: .number)
                            .keyboardType(.decimalPad)
                    }
                    
                    // Currency Picker
                    Picker("Currency", selection: $currency) {
                        ForEach(CurrencyService.shared.availableCurrencies, id: \.self) { code in
                            Text("\(CurrencyService.shared.symbol(for: code)) (\(code))").tag(code)
                        }
                    }
                }
                
                if type == .cash {
                    Section {
                        Text("Transactions linked to this Account ID will automatically adjust the Current Balance based on the Initial Balance.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Asset" : "Add Asset")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveAsset()
                    }
                    .disabled(name.isEmpty || (type == .cash && value == nil && initialBalance == nil))
                }
            }
            .onAppear {
                if let passedAsset = assetToEdit {
                    print("DEBUG: AssetEditor onAppear - Passed Asset: \(passedAsset.ticker). Cached MV: \(passedAsset.marketValue)")
                    
                    // Force a fetch from a FRESH Context to ensure we get the latest data updated by the background actor
                    let freshContext = ModelContext(modelContext.container)
                    freshContext.autosaveEnabled = false
                    
                    // Robust Fetch using PersistentModelID
                    let id = passedAsset.persistentModelID
                    
                    if let freshAsset = freshContext.model(for: id) as? AssetEntity {
                        print("DEBUG: AssetEditor - Fresh Context Fetch Success via ID. MV: \(freshAsset.marketValue), Cash: \(freshAsset.cashBalance ?? -1)")
                        name = freshAsset.ticker
                        holdings = NSDecimalNumber(decimal: freshAsset.holdings).doubleValue
                        if freshAsset.type == .cash {
                            value = NSDecimalNumber(decimal: freshAsset.cashBalance ?? 0).doubleValue
                        } else {
                            value = NSDecimalNumber(decimal: freshAsset.marketValue).doubleValue
                        }
                        type = freshAsset.type
                        currency = freshAsset.currency
                        customID = freshAsset.customID ?? ""
                        initialBalance = NSDecimalNumber(decimal: freshAsset.initialBalance).doubleValue
                    } else {
                        print("DEBUG: AssetEditor - Fresh Fetch Failed (ID lookup failed), using passed asset.")
                        // Fallback
                        name = passedAsset.ticker
                        holdings = NSDecimalNumber(decimal: passedAsset.holdings).doubleValue
                        if passedAsset.type == .cash {
                            value = NSDecimalNumber(decimal: passedAsset.cashBalance ?? 0).doubleValue
                        } else {
                            value = NSDecimalNumber(decimal: passedAsset.marketValue).doubleValue
                        }
                        type = passedAsset.type
                        currency = passedAsset.currency
                        customID = passedAsset.customID ?? ""
                        initialBalance = NSDecimalNumber(decimal: passedAsset.initialBalance).doubleValue
                    }
                }
            }
            }
        }
    
    
    func saveAsset() {
        let finalHoldings = (type == .cash) ? 1 : (Decimal(holdings ?? 0))
        let finalValue = Decimal(value ?? 0)
        let finalInitial = Decimal(initialBalance ?? 0)
        let finalCustomID = customID.isEmpty ? nil : customID
        
        // Polymorphic Save Logic
        // For Cash: value -> cashBalance, marketValue -> 0
        // For Stock: value -> marketValue, cashBalance -> nil
        
        let targetMarketValue = (type == .cash) ? 0 : finalValue
        let targetCashBalance = (type == .cash) ? finalValue : nil
        
        if let existingAsset = assetToEdit {
            // Update existing
            existingAsset.ticker = name
            existingAsset.holdings = finalHoldings
            existingAsset.marketValue = targetMarketValue
            existingAsset.cashBalance = targetCashBalance
            existingAsset.type = type
            existingAsset.currency = currency
            existingAsset.customID = finalCustomID
            existingAsset.initialBalance = finalInitial
            existingAsset.lastUpdated = Date()
        } else {
            // Create new
            let asset = AssetEntity(
                ticker: name,
                holdings: finalHoldings,
                marketValue: targetMarketValue,
                type: type,
                currency: currency,
                customID: finalCustomID,
                initialBalance: finalInitial,
                cashBalance: targetCashBalance
            )
            modelContext.insert(asset)
        }
        
        // Critical: Explicitly save context after edit to ensure disk persistence
        try? modelContext.save()
        
        // Trigger Engine just in case details changed that affect calculation
        let container = modelContext.container
        Task {
            let engine = FinancialEngine(modelContainer: container)
            await engine.recalculateAssetBalances()
        }
        
        triggerHaptic(.hustle)
        isPresented = false
    }
}

extension Int {
    var formattedWithSeparator: String {
        return NumberFormatter.localizedString(from: NSNumber(value: self), number: .decimal)
    }
}
