import SwiftUI
import SwiftData

struct LensView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PhysicalAsset.purchaseDate, order: .reverse) private var assets: [PhysicalAsset]
    
    @State private var showAddSheet = false
    @State private var selectedAsset: PhysicalAsset? = nil
    
    // Convert all values to base currency before summing
    var totalValue: Decimal {
        assets.filter { $0.status == .active }.reduce(0) { total, asset in
            total + CurrencyService.shared.convertToBase(asset.purchaseValue, from: asset.currency)
        }
    }
    
    var dailyCost: Decimal {
        assets.reduce(0) { total, asset in
            total + CurrencyService.shared.convertToBase(asset.costPerDay, from: asset.currency)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header: Large Bold Title + Subtitle (Left Aligned)
            VStack(alignment: .leading, spacing: 4) {
                Text("Gear")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.lizhiTextPrimary)
                
                Text("Total: \(CurrencyService.shared.symbol(for: CurrencyService.shared.baseCurrency))\(Int(NSDecimalNumber(decimal: totalValue).doubleValue).formattedWithSeparator)")
                    .font(.subheadline)
                    .foregroundStyle(Color.lizhiTextSecondary)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 20)
            
            // Stats Card
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("TOTAL ITEMS")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.lizhiTextSecondary)
                    Text("\(assets.count)")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.lizhiTextPrimary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("DAILY COST")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.lizhiTextSecondary)
                    Text("-\(CurrencyService.shared.symbol(for: CurrencyService.shared.baseCurrency))\(String(format: "%.2f", Double(truncating: dailyCost as NSNumber)))")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(.orange)
                }
            }
            .padding()
            .background(Color.lizhiSurface)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
            
            // Assets List - Using List for swipe actions
            List {
                ForEach(assets) { asset in
                    PhysicalAssetRow(asset: asset)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedAsset = asset
                            showAddSheet = true
                            triggerHaptic(.glassTap)
                        }
                        .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                modelContext.delete(asset)
                                triggerHaptic(.glassTap)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
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
        .sheet(isPresented: $showAddSheet) {
            PhysicalAssetEditor(isPresented: $showAddSheet, assetToEdit: selectedAsset)
        }
        .onChange(of: showAddSheet) { _, newValue in
            if !newValue {
                selectedAsset = nil // Clear selection when sheet closes
            }
        }
    }
}

struct PhysicalAssetRow: View {
    let asset: PhysicalAsset
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon / Image Placeholder
            ZStack {
                Color.lizhiTextPrimary // Inverted contrast background for icon
                Image(systemName: asset.icon)
                    .font(.title2)
                    .foregroundStyle(Color.lizhiBackground)
            }
            .frame(width: 60, height: 60)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(asset.name)
                        .font(.headline)
                        .foregroundStyle(Color.lizhiTextPrimary)
                    Spacer()
                    StatusBadge(status: asset.status)
                }
                
                HStack {
                    Text("Bought: \(asset.purchaseDate.formatted(date: .numeric, time: .omitted))")
                        .font(.caption)
                        .foregroundStyle(Color.lizhiTextSecondary)
                    
                    if asset.isInsured {
                        Image(systemName: "shield.fill")
                            .font(.caption2)
                            .foregroundStyle(.blue)
                        Text("Insured")
                            .font(.caption2)
                            .foregroundStyle(.blue)
                    }
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing) {
                Text("\(CurrencyService.shared.symbol(for: asset.currency.isEmpty ? "AUD" : asset.currency))\(Int(NSDecimalNumber(decimal: asset.purchaseValue).doubleValue))")
                    .font(.headline)
                    .foregroundStyle(Color.lizhiTextPrimary)
                Text("-\(CurrencyService.shared.symbol(for: CurrencyService.shared.baseCurrency))\(Double(truncating: asset.costPerDay as NSNumber), specifier: "%.2f")/d")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .padding()
        .background(Color.lizhiSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.lizhiTextSecondary.opacity(0.1), lineWidth: 1))
    }
}

struct StatusBadge: View {
    let status: PhysicalAssetStatus
    
    var color: Color {
        switch status {
        case .active: return .green
        case .retired: return .gray
        case .sold: return .blue
        case .lost: return .red
        }
    }
    
    var body: some View {
        Text(status.rawValue)
            .font(.caption2)
            .fontWeight(.bold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.2))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}

// Editor
struct PhysicalAssetEditor: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var isPresented: Bool
    var assetToEdit: PhysicalAsset? = nil
    
    @State private var name: String = ""
    @State private var value: Double?
    @State private var date: Date = Date()
    @State private var status: PhysicalAssetStatus = .active
    @State private var isInsured: Bool = false
    @State private var currency: String = CurrencyService.shared.baseCurrency
    
    var isEditing: Bool { assetToEdit != nil }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Name (e.g. Sony A7 III)", text: $name)
                    TextField("Value", value: $value, format: .number)
                        .keyboardType(.decimalPad)
                    DatePicker("Bought", selection: $date, displayedComponents: .date)
                    
                    // Currency Picker
                    Picker("Currency", selection: $currency) {
                        ForEach(CurrencyService.shared.availableCurrencies, id: \.self) { code in
                            Text("\(CurrencyService.shared.symbol(for: code)) (\(code))").tag(code)
                        }
                    }
                }
                
                Section("Status") {
                    Picker("Status", selection: $status) {
                        ForEach(PhysicalAssetStatus.allCases, id: \.self) { s in
                            Text(s.rawValue).tag(s)
                        }
                    }
                }
                
                Section("Insurance") {
                    Toggle("Insured?", isOn: $isInsured)
                }
            }
            .navigationTitle(isEditing ? "Edit Gear" : "Add Gear")
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
            .onAppear {
                if let asset = assetToEdit {
                    name = asset.name
                    value = NSDecimalNumber(decimal: asset.purchaseValue).doubleValue
                    date = asset.purchaseDate
                    status = asset.status
                    isInsured = asset.isInsured
                    currency = asset.currency
                }
            }
        }
    }
    
    func saveAsset() {
        guard let v = value else { return }
        
        if let existingAsset = assetToEdit {
            // Update existing
            existingAsset.name = name
            existingAsset.purchaseValue = Decimal(v)
            existingAsset.purchaseDate = date
            existingAsset.status = status
            existingAsset.isInsured = isInsured
            existingAsset.currency = currency
        } else {
            // Create new
            let asset = PhysicalAsset(
                name: name,
                purchaseValue: Decimal(v),
                purchaseDate: date,
                status: status,
                isInsured: isInsured,
                currency: currency
            )
            modelContext.insert(asset)
        }
        
        triggerHaptic(.hustle)
        isPresented = false
    }
}

