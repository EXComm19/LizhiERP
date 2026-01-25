import SwiftUI
import SwiftData

struct LensView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PhysicalAsset.purchaseDate, order: .reverse) private var assets: [PhysicalAsset]
    
    @State private var showAddSheet = false
    
    var totalValue: Decimal {
        assets.filter { $0.status == .active }.reduce(0) { $0 + $1.purchaseValue }
    }
    
    var dailyCost: Decimal {
        assets.reduce(0) { $0 + $1.costPerDay }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 1. Header with Stats
            VStack(alignment: .leading, spacing: 16) {
                Text("Gear")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("TOTAL VALUE")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(.gray)
                        Text("$\(Int(NSDecimalNumber(decimal: totalValue).doubleValue))")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("DAILY COST")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(.gray)
                        Text("-\(Double(truncating: dailyCost as NSNumber), specifier: "%.2f")")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(.orange)
                    }
                }
                .padding()
                .background(Color(hex: "1A1A1A"))
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.1), lineWidth: 1))
            }
            .padding()
            .padding(.top, 40)
            
            // 2. List
            List {
                ForEach(assets) { asset in
                    PhysicalAssetRow(asset: asset)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .swipeActions {
                            Button(role: .destructive) {
                                modelContext.delete(asset)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
        .background(Color.black.ignoresSafeArea())
        .sheet(isPresented: $showAddSheet) {
            PhysicalAssetEditor(isPresented: $showAddSheet)
        }
        // Need to expose a trigger for the RootView FAB content-aware usage
        // But for now, since this is a View inside RootView, 
        // RootView handles the FAB tap. We need `showAddSheet` to be toggleable from outside or 
        // unify the state. For now, let's keep it separate and clean up later.
        .onChange(of: showAddSheet) { _, _ in
           // sync?
        }
    }
}

struct PhysicalAssetRow: View {
    let asset: PhysicalAsset
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon / Image Placeholder
            ZStack {
                Color.black
                Image(systemName: asset.icon)
                    .font(.title2)
                    .foregroundStyle(.white)
            }
            .frame(width: 60, height: 60)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1), lineWidth: 1))
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(asset.name)
                        .font(.headline)
                        .foregroundStyle(.white)
                    Spacer()
                    StatusBadge(status: asset.status)
                }
                
                HStack {
                    Text("Bought: \(asset.purchaseDate.formatted(date: .numeric, time: .omitted))")
                        .font(.caption)
                        .foregroundStyle(.gray)
                    
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
                Text("$\(Int(NSDecimalNumber(decimal: asset.purchaseValue).doubleValue))")
                    .font(.headline)
                    .foregroundStyle(.white)
                Text("-\(Double(truncating: asset.costPerDay as NSNumber), specifier: "%.2f")/day")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .padding()
        .background(Color(hex: "1A1A1A"))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.05), lineWidth: 1))
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
    
    @State private var name: String = ""
    @State private var value: Double?
    @State private var date: Date = Date()
    @State private var status: PhysicalAssetStatus = .active
    @State private var isInsured: Bool = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Name (e.g. Sony A7 III)", text: $name)
                    TextField("Value", value: $value, format: .number)
                        .keyboardType(.decimalPad)
                    DatePicker("Bought", selection: $date, displayedComponents: .date)
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
            .navigationTitle("Add Gear")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let v = value {
                            let asset = PhysicalAsset(
                                name: name,
                                purchaseValue: Decimal(v),
                                purchaseDate: date,
                                status: status,
                                isInsured: isInsured
                            )
                            modelContext.insert(asset)
                            isPresented = false
                        }
                    }
                    .disabled(name.isEmpty || value == nil)
                }
            }
        }
    }
}

