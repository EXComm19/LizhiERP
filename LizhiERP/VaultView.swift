import SwiftUI
import SwiftData

struct VaultView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \AssetEntity.lastUpdated, order: .reverse) private var assets: [AssetEntity]
    
    // Editor State
    @State private var showAssetEditor: Bool = false
    
    // Derived
    var totalNetWorth: Decimal {
        assets.reduce(0) { $0 + $1.totalValue }
    }
    
    var cashAssets: [AssetEntity] {
        assets.filter { $0.type == .cash }
    }
    
    var stockAssets: [AssetEntity] {
        assets.filter { $0.type == .stock || $0.type == .crypto } // Group crypto with stock or separate? Design shows Stock separately. 
    }
    
    var otherAssets: [AssetEntity] {
        assets.filter { $0.type == .other }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 1. Unified Header
            PageHeader(
                title: "Vault",
                centerContent: {
                   VStack(spacing: 2) {
                       Text("NET WORTH")
                           .font(.caption2)
                           .fontWeight(.bold)
                           .foregroundStyle(.gray)
                       Text("$\(Int(NSDecimalNumber(decimal: totalNetWorth).doubleValue).formattedWithSeparator)")
                           .font(.headline)
                           .fontWeight(.bold)
                           .foregroundStyle(.white)
                   }
                }
            )
            
            // 2. List Content
            List {
                // CASH SECTION
                if !cashAssets.isEmpty {
                    Section {
                        ForEach(cashAssets) { asset in
                            VaultAssetRow(asset: asset, icon: "wallet.pass.fill", iconColor: .blue)
                        }
                        .onDelete(perform: { deleteAsset(at: $0, from: cashAssets) })
                    } header: {
                        Text("CASH")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(.gray)
                            .kerning(1.2)
                            .listRowInsets(EdgeInsets(top: 20, leading: 16, bottom: 8, trailing: 16))
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
                
                // STOCK SECTION
                if !stockAssets.isEmpty {
                    Section {
                        ForEach(stockAssets) { asset in
                            VaultAssetRow(asset: asset, icon: "chart.line.uptrend.xyaxis", iconColor: .green)
                        }
                        .onDelete(perform: { deleteAsset(at: $0, from: stockAssets) })
                    } header: {
                        Text("STOCK")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(.gray)
                            .kerning(1.2)
                            .listRowInsets(EdgeInsets(top: 20, leading: 16, bottom: 8, trailing: 16))
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
                
                // OTHER SECTION
                if !otherAssets.isEmpty {
                    Section {
                        ForEach(otherAssets) { asset in
                            VaultAssetRow(asset: asset, icon: "cube.box.fill", iconColor: .purple)
                        }
                        .onDelete(perform: { deleteAsset(at: $0, from: otherAssets) })
                    } header: {
                        Text("OTHER")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(.gray)
                            .kerning(1.2)
                            .listRowInsets(EdgeInsets(top: 20, leading: 16, bottom: 8, trailing: 16))
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
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
        .background(Color.black.ignoresSafeArea())
        .sheet(isPresented: $showAssetEditor) {
            VaultAssetEditor(isPresented: $showAssetEditor)
        }
        // Sync with RootView? 
        // Ideally RootView's FAB opens this sheet. 
        // Since `showAssetEditor` is local State here, RootView can't toggle it easily unless we use bindings
        // or a shared store.
        // Given I updated RootView to have its own `showAssetEditor` state, 
        // I actually need `VaultAssetEditor` to be available. 
        // I will define `VaultAssetEditor` in this file so RootView can use it.
    }
    
    func deleteAsset(at offsets: IndexSet, from list: [AssetEntity]) {
        for index in offsets {
            let asset = list[index]
            modelContext.delete(asset)
            triggerHaptic(.glassTap)
        }
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
                .fill(Color(hex: "1A1A1A")) // Darker inner bg
                .frame(width: 48, height: 48)
                .overlay(
                    Image(systemName: icon)
                        .foregroundStyle(iconColor)
                        .font(.title3)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(asset.ticker)
                    .font(.headline)
                    .foregroundStyle(.white)
                
                // Subtitle: e.g. "12500 AUD" or "150 IVV"
                Text("\(asset.holdings.formatted()) \(asset.currency.isEmpty ? "Units" : asset.currency)")
                    .font(.caption)
                    .foregroundStyle(.gray)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("$\(Int(NSDecimalNumber(decimal: asset.totalValue).doubleValue).formattedWithSeparator)")
                    .font(.headline) // Make it bold/prominent
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                
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
        .background(Color(hex: "111111")) // Dark Card
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.1), lineWidth: 1))
    }
}

// MARK: - Editor

struct VaultAssetEditor: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var isPresented: Bool
    
    @State private var name: String = "" // Ticker/Name
    @State private var holdings: Double?
    @State private var value: Double? // Market Value / Balance
    @State private var type: AssetType = .cash
    @State private var currency: String = "AUD"
    
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
                        TextField("Balance", value: $value, format: .number)
                            .keyboardType(.decimalPad)
                        // Hidden holdings = 1 implicitly
                    } else {
                        TextField("Units Held", value: $holdings, format: .number)
                            .keyboardType(.decimalPad)
                        TextField("Price per Unit", value: $value, format: .number)
                            .keyboardType(.decimalPad)
                        TextField("Currency/Symbol (e.g. AUD, USD)", text: $currency)
                    }
                }
            }
            .navigationTitle("Add Asset")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveAsset()
                    }
                    .disabled(name.isEmpty || value == nil)
                }
            }
        }
    }
    
    func saveAsset() {
        let finalHoldings = (type == .cash) ? 1 : (Decimal(holdings ?? 0))
        let finalValue = Decimal(value ?? 0)
        
        let asset = AssetEntity(
            ticker: name,
            holdings: finalHoldings,
            marketValue: finalValue,
            type: type,
            currency: currency
        )
        modelContext.insert(asset)
        triggerHaptic(.hustle)
        isPresented = false
    }
}

extension Int {
    var formattedWithSeparator: String {
        return NumberFormatter.localizedString(from: NSNumber(value: self), number: .decimal)
    }
}
