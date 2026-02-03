import SwiftUI
import SwiftData

struct VaultView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \AssetEntity.lastUpdated, order: .reverse) private var assets: [AssetEntity]
    
    // Editor State
    @State private var showAssetEditor: Bool = false
    @State private var selectedAsset: AssetEntity? = nil
    @State private var showStockDetail: Bool = false
    
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
                
                Text("Total: \(CurrencyService.shared.symbol(for: CurrencyService.shared.baseCurrency))\(NSDecimalNumber(decimal: totalNetWorth).doubleValue.formatted(.number.precision(.fractionLength(2))))")
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
                                    showStockDetail = true
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
        .sheet(isPresented: $showStockDetail) {
            if let asset = selectedAsset {
                StockDetailView(asset: asset)
            } else {
                Text("No asset selected")
                    .foregroundStyle(.red)
            }
        }
        .onChange(of: showAssetEditor) { _, newValue in
            if !newValue {
                selectedAsset = nil // Clear selection when sheet closes
            }
        }
        .onChange(of: showStockDetail) { _, newValue in
            if !newValue {
                selectedAsset = nil // Clear selection when stock detail closes
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
    
    // logic extraction for ViewBuilder compatibility
    private var gainPercent: Double {
        if let initial = asset.initialValue, initial > 0 {
             let profit = asset.totalValue - initial
             let initialDouble = NSDecimalNumber(decimal: initial).doubleValue
             let profitDouble = NSDecimalNumber(decimal: profit).doubleValue
             return (profitDouble / initialDouble) * 100
        }
        return 0.0
    }
    
    var body: some View {
        if asset.type == .cash {
            CashAssetCard(
                name: asset.ticker,
                accountId: asset.customID ?? "No ID",
                balance: NSDecimalNumber(decimal: asset.totalValue).doubleValue,
                currency: asset.currency,
                brandDomain: asset.brandDomain
            )
        } else if asset.type == .stock || asset.type == .crypto {
            InvestmentAssetCard(
                ticker: asset.ticker,
                name: asset.ticker, // Or descriptive name if available
                units: NSDecimalNumber(decimal: asset.holdings).doubleValue,
                price: NSDecimalNumber(decimal: asset.marketValue).doubleValue,
                changePercent: gainPercent, 
                currency: asset.currency
            )
        } else {
            // Fallback for other types
            HStack(spacing: 16) {
                Circle()
                    .fill(Color.lizhiSurface)
                    .frame(width: 48, height: 48)
                    .overlay(Image(systemName: icon).foregroundStyle(iconColor))
                
                VStack(alignment: .leading) {
                    Text(asset.ticker).font(.headline).foregroundStyle(Color.lizhiTextPrimary)
                    Text("\(asset.holdings) units").font(.caption).foregroundStyle(Color.lizhiTextSecondary)
                }
                Spacer()
                Text(CurrencyService.shared.format(asset.totalValue, currency: asset.currency))
                    .font(.headline).fontWeight(.bold).foregroundStyle(Color.lizhiTextPrimary)
            }
            .padding().background(Color.lizhiSurface).clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
}

// MARK: - Cash Asset Card
struct CashAssetCard: View {
    let name: String
    let accountId: String
    let balance: Double
    let currency: String
    let brandDomain: String?
    
    var body: some View {
        ZStack {
            // Card Background
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(hex: "1C1C1E"))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
            
            HStack(spacing: 16) {
                // Icon Container
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 48, height: 48)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                        )
                    
                    if let domain = brandDomain, !domain.isEmpty {
                         let logoURLString = "https://img.logo.dev/\(domain)?token=pk_EcUNocp3RJOn4qZwg9KGTA&size=200&format=png&retina=true"
                         
                         CachedLogoView(url: URL(string: logoURLString)) {
                             // Fallback / Loading
                             Image(systemName: "wallet.pass.fill")
                                 .font(.system(size: 24))
                                 .foregroundStyle(Color.blue)
                         } content: { image in
                             image
                                 .resizable()
                                 .aspectRatio(contentMode: .fit)
                                 .frame(width: 48, height: 48) // Fill container
                                 .clipShape(RoundedRectangle(cornerRadius: 14))
                         }
                    } else {
                        Image(systemName: "wallet.pass.fill")
                            .font(.system(size: 24)) 
                            .foregroundStyle(Color.blue)
                    }
                }
                
                // Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(name)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    
                    Text(accountId)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.white.opacity(0.4))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                
                Spacer()
                
                // Balance
                VStack(alignment: .trailing, spacing: 2) {
                    Text(CurrencyService.shared.format(Decimal(balance), currency: currency))
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .fontDesign(.rounded)
                    
                    Text("Available")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.white.opacity(0.4))
                }
            }
            .padding(16)
        }
    }
}

// MARK: - Investment Asset Card
struct InvestmentAssetCard: View {
    let ticker: String
    let name: String
    let units: Double
    let price: Double
    let changePercent: Double
    let currency: String
    
    var isPositive: Bool { changePercent >= 0 }
    var totalValue: Double { units * price }
    
    var body: some View {
        ZStack {
            // Card Background
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(hex: "1C1C1E"))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
            
            VStack(spacing: 12) {
                // Top Row
                HStack(alignment: .top) {
                    HStack(spacing: 12) {
                        // Icon Container
                        ZStack {
                            RoundedRectangle(cornerRadius: 14, style: .continuous) // Match Cash Card (14)
                                .fill(isPositive ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
                                .frame(width: 48, height: 48) // Match Cash Card (48)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(isPositive ? Color.green.opacity(0.2) : Color.red.opacity(0.2), lineWidth: 1)
                                )
                            
                            let tickerLogoURL = "https://img.logo.dev/ticker/\(ticker)?token=pk_EcUNocp3RJOn4qZwg9KGTA&size=200&retina=true"
                            
                            CachedLogoView(url: URL(string: tickerLogoURL)) {
                                // Fallback / Loading
                                Image(systemName: "chart.line.uptrend.xyaxis")
                                    .font(.system(size: 22))
                                    .foregroundStyle(isPositive ? Color.green : Color.red)
                            } content: { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 48, height: 48) // Fill container
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(ticker)
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                            
                            Text(name)
                                .font(.caption)
                                .foregroundStyle(Color.white.opacity(0.4))
                                .lineLimit(1)
                        }
                    }
                    
                    Spacer()
                    
                    // Change Badge
                    HStack(spacing: 4) {
                        Image(systemName: isPositive ? "arrow.up.right" : "arrow.down.right")
                            .font(.caption2)
                        Text("\(abs(changePercent).formatted(.number.precision(.fractionLength(1))))%")
                            .font(.caption2)
                            .fontWeight(.bold)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(isPositive ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
                    .foregroundStyle(isPositive ? .green : .red)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isPositive ? Color.green.opacity(0.2) : Color.red.opacity(0.2), lineWidth: 1)
                    )
                }
                
                Divider().background(Color.white.opacity(0.05))
                
                // Bottom Row
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Position")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundStyle(Color.white.opacity(0.4))
                        
                        HStack(spacing: 4) {
                            Text("\(units.formatted())")
                                .foregroundStyle(Color.white.opacity(0.8))
                            Text("×")
                                .foregroundStyle(Color.white.opacity(0.3))
                            Text(CurrencyService.shared.format(Decimal(price), currency: currency))
                                .foregroundStyle(Color.white.opacity(0.8))
                        }
                        .font(.caption)
                        .fontDesign(.monospaced)
                    }
                    
                    Spacer()
                    
                    Text(CurrencyService.shared.format(Decimal(totalValue), currency: currency))
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .fontDesign(.rounded)
                }
            }
            .padding(16)
        }
    }
}

// Extension needed if not already present
extension CurrencyService {
    func format(_ amount: Decimal, currency: String) -> String {
        return "\(symbol(for: currency))\(NSDecimalNumber(decimal: amount).doubleValue.formatted(.number.precision(.fractionLength(2))))"
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
    @State private var brandDomain: String = "" // [NEW]
    
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
                        
                        TextField("Brand Domain (e.g. westpac.com)", text: $brandDomain)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.URL)
                        
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
                        brandDomain = freshAsset.brandDomain ?? ""
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
                        brandDomain = passedAsset.brandDomain ?? ""
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
        let finalBrandDomain = brandDomain.isEmpty ? nil : brandDomain
        
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
            existingAsset.brandDomain = finalBrandDomain
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
                cashBalance: targetCashBalance,
                brandDomain: finalBrandDomain
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
