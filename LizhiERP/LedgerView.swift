import SwiftUI
import SwiftData

struct LedgerView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Transaction.date, order: .reverse) private var allTransactions: [Transaction]
    @Query private var categories: [CategoryEntity]
    
    // State
    @State private var displayDate: Date = Date()
    @State private var searchText: String = ""
    @State private var isFilterOpen: Bool = false
    @State private var selectedType: TransactionType? = nil
    @State private var selectedCategory: TransactionCategory? = nil
    @State private var showDatePicker = false
    
    // Filtering Logic (Scoped to Display Month)
    var filteredTransactions: [Transaction] {
        let calendar = Calendar.current
        return allTransactions.filter { tx in
            // 1. Month Scope (Base Filter)
            let matchMonth = calendar.isDate(tx.date, equalTo: displayDate, toGranularity: .month)
            if !matchMonth { return false }
            
            // 2. Search Text
            let matchSearch = searchText.isEmpty ||
                tx.subcategory.localizedCaseInsensitiveContains(searchText) ||
                tx.category.rawValue.localizedCaseInsensitiveContains(searchText) ||
                tx.contextTags.contains { $0.localizedCaseInsensitiveContains(searchText) }
            
            // 3. Type Filter
            let matchType = selectedType == nil || tx.type == selectedType
            
            // 4. Category Filter
            let matchCategory = selectedCategory == nil || tx.category == selectedCategory
            
            return matchSearch && matchType && matchCategory
        }
    }
    
    // Grouping by Day
    var groupedTransactions: [(Date, [Transaction])] {
        let grouped = Dictionary(grouping: filteredTransactions) { tx in
            Calendar.current.startOfDay(for: tx.date)
        }
        return grouped.sorted { $0.key > $1.key }
    }
    
    var body: some View {
        ZStack {
            Color.lizhiBackground.ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 0) {
                // Header: Large Bold Title (Left Aligned)
                HStack {
                    Text("Ledger")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.lizhiTextPrimary)
                    
                    Spacer()
                    
                    // Actions
                    HStack(spacing: 12) {
                        // Filter Toggle
                        Button {
                            withAnimation { isFilterOpen.toggle() }
                        } label: {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                                .font(.title3)
                                .foregroundStyle(isFilterOpen ? .orange : Color.lizhiTextPrimary)
                                .padding(8)
                                .background(Color.lizhiSurface)
                                .clipShape(Circle())
                        }
                        
                        // Import/Export Menu
                        Menu {
                            Button {
                                showImporter = true
                            } label: {
                                Label("Import CSV", systemImage: "square.and.arrow.down")
                            }
                            
                            ShareLink(item: csvFile, preview: SharePreview("Lizhi Export", image: Image(systemName: "tablecells"))) {
                                Label("Export CSV", systemImage: "square.and.arrow.up")
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.title3)
                                .foregroundStyle(Color.lizhiTextPrimary)
                                .padding(8)
                                .background(Color.lizhiSurface)
                                .clipShape(Circle())
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 12)
                
                // Month Navigator
                HStack {
                    Button {
                        moveMonth(by: -1)
                    } label: {
                        Image(systemName: "chevron.left")
                            .foregroundStyle(Color.lizhiTextSecondary)
                            .padding(8)
                    }
                    
                    Button {
                        showDatePicker = true 
                    } label: {
                        HStack(spacing: 4) {
                            Text(displayDate.formatted(.dateTime.month(.wide).year()))
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundStyle(Color.lizhiTextPrimary)
                            Image(systemName: "chevron.down")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundStyle(Color.lizhiTextSecondary)
                        }
                    }
                    
                    Button {
                        moveMonth(by: 1)
                    } label: {
                        Image(systemName: "chevron.right")
                            .foregroundStyle(Color.lizhiTextSecondary)
                            .padding(8)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
                
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(Color.lizhiTextSecondary)
                    TextField("Search transactions...", text: $searchText)
                        .foregroundStyle(Color.lizhiTextPrimary)
                        .tint(.orange)
                    if !searchText.isEmpty {
                        Button { searchText = "" } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(Color.lizhiTextSecondary)
                        }
                    }
                }
                .padding()
                .background(Color.lizhiSurface)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 20)
                .padding(.bottom, 10)
                
                // Expandable Filter Panel
                if isFilterOpen {
                    VStack(alignment: .leading, spacing: 16) {
                        
                        // Type Segment
                        Picker("Type", selection: $selectedType) {
                            Text("All").tag(TransactionType?.none)
                            Text("Expense").tag(TransactionType?.some(.expense))
                            Text("Income").tag(TransactionType?.some(.income))
                        }
                        .pickerStyle(.segmented)
                        .colorMultiply(.orange)
                        
                        // Category Scroll
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                Button { selectedCategory = nil } label: {
                                    Text("All Categories")
                                        .filterChip(isSelected: selectedCategory == nil)
                                }
                                ForEach(TransactionCategory.allCases, id: \.self) { cat in
                                    Button { selectedCategory = cat } label: {
                                        Text(cat.rawValue)
                                            .filterChip(isSelected: selectedCategory == cat)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.vertical)
                    .padding(.horizontal, 20)
                    .background(Color.lizhiSurface)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                // List
                List {
                    ForEach(groupedTransactions, id: \.0) { (day, txs) in
                        Section {
                            ForEach(txs) { tx in
                                TransactionRow(tx: tx, categories: categories)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        // FIX: Simply set the selected item. No boolean toggle needed.
                                        selectedTransaction = tx
                                        triggerHaptic(.glassTap)
                                    }
                                    .listRowInsets(EdgeInsets(top: 4, leading: 20, bottom: 4, trailing: 20))
                                    .listRowBackground(Color.clear)
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            deleteTransaction(tx)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                            }
                        } header: {
                            HStack {
                                Text(day.formatted(.dateTime.weekday(.wide).day().month(.abbreviated)))
                                    .font(.footnote)
                                    .fontWeight(.bold)
                                    .foregroundStyle(Color.lizhiTextSecondary)
                                    .textCase(.uppercase)
                                Spacer()
                                // Summation here does not respect currency conversion.
                                // It just sums values. For a ledger list, this might be okay or misleading.
                                // Let's keep as is but fix style.
                                Text("$\(totalForDay(txs).formattedWithSeparator)")
                                    .font(.caption)
                                    .foregroundStyle(Color.lizhiTextSecondary)
                            }
                            .padding(.vertical, 8)
                            .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
                        }
                        .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        // FIX: Use .sheet(item:) instead of .sheet(isPresented:)
        // This ensures the sheet is ONLY created when selectedTransaction is non-nil.
        .sheet(item: $selectedTransaction) { tx in
            ManualTransactionView(
                isPresented: Binding(
                    get: { selectedTransaction != nil },
                    set: { if !$0 { selectedTransaction = nil } }
                ),
                transactionToEdit: tx
            )
        }
        .sheet(isPresented: $showDatePicker) {
            MonthYearPickerView(selectedDate: $displayDate, isPresented: $showDatePicker)
                .presentationDetents([.fraction(0.4)])
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.commaSeparatedText], allowsMultipleSelection: false) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    importCSV(url)
                }
            case .failure(let error):
                print("Import failed: \(error.localizedDescription)")
            }
        }
        .overlay {
            if isImporting {
                ZStack {
                    Color.black.opacity(0.6).ignoresSafeArea()
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                            .tint(.white)
                        
                        Text("Importing Data...")
                            .font(.headline)
                            .foregroundStyle(.white)
                        
                        ProgressView(value: importProgress)
                            .progressViewStyle(.linear)
                            .tint(.orange)
                            .frame(width: 200)
                        
                        Text("\(Int(importProgress * 100))%")
                            .font(.caption)
                            .foregroundStyle(.gray)
                    }
                    .padding(32)
                    .background(Color(hex: "1A1A1A"))
                    .cornerRadius(16)
                    .shadow(radius: 20)
                }
            }
        }
    }
    
    @Environment(\.modelContext) private var modelContext
    
    // Import/Export
    @State private var showImporter = false
    @State private var isImporting = false
    @State private var importProgress: Double = 0.0
    
    // Editing
    // FIX: Removed 'showEditor' bool. We now rely solely on selectedTransaction being non-nil.
    @State private var selectedTransaction: Transaction? = nil

    var isFilterActive: Bool {
        selectedType != nil || selectedCategory != nil
    }
    
    // Helper to delete
    func deleteTransaction(_ tx: Transaction) {
        modelContext.delete(tx)
        triggerHaptic(.glassTap)
    }
    
    // Export Logic using Transferable
    var csvFile: CSVDocument {
        CSVDocument(transactions: allTransactions)
    }
    
    // Import Logic
    func importCSV(_ url: URL) {
        guard url.startAccessingSecurityScopedResource() else { return }
        
        // Copy to temp
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent(url.lastPathComponent)
        
        do {
            if FileManager.default.fileExists(atPath: tempFile.path) {
                try FileManager.default.removeItem(at: tempFile)
            }
            try FileManager.default.copyItem(at: url, to: tempFile)
        } catch {
            print("Failed to copy file: \(error)")
            url.stopAccessingSecurityScopedResource()
            return
        }
        
        url.stopAccessingSecurityScopedResource()
        
        // Run in background
        Task {
            do {
                var content = ""
                if let str = try? String(contentsOf: tempFile, encoding: .utf8) {
                    content = str
                } else {
                    content = try String(contentsOf: tempFile)
                }
                
                // Use the unified CSVImportService!
                let result = await CSVImportService.processCSV(content: content)
                
                try? FileManager.default.removeItem(at: tempFile)
                
                await MainActor.run {
                    // Init progress UI state if needed, but LedgerView currently doesn't have the overlay built-in like SettingsView
                    // We should add it or just rely on console/haptic?
                    // User request implies visible progress.
                    // Let's add the state to LedgerView first.
                    isImporting = true
                    importProgress = 0.1
                    
                    Task {
                        var count = 0
                        let total = Double(result.transactions.count)
                        
                        for tx in result.transactions {
                            modelContext.insert(tx)
                            count += 1
                            if count % 50 == 0 {
                                importProgress = 0.1 + (0.9 * (Double(count) / total))
                                try? await Task.sleep(nanoseconds: 10_000_000)
                            }
                        }
                        try? modelContext.save()
                        print("Imported \(result.transactions.count) transactions")
                        triggerHaptic(.hustle)
                        isImporting = false
                    }
                    }
    

            } catch {
                print("Import failed: \(error)")
            }
        }
    }
    
    // Helpers
    func moveMonth(by value: Int) {
        if let newDate = Calendar.current.date(byAdding: .month, value: value, to: displayDate) {
            displayDate = newDate
            triggerHaptic(.glassTap) // Correction: Using valid haptic style
        }
    }
    
    func totalForDay(_ txs: [Transaction]) -> Int {
        let total = txs.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount }
        return NSDecimalNumber(decimal: total).intValue
    }
}

// Custom Transferable & FileDocument
import UniformTypeIdentifiers
import CoreTransferable

struct CSVDocument: FileDocument, Transferable {
    static var readableContentTypes: [UTType] { [.commaSeparatedText] }
    
    var transactions: [Transaction]
    
    init(transactions: [Transaction] = []) {
        self.transactions = transactions
    }
    
    init(configuration: ReadConfiguration) throws {
        self.transactions = []
    }
    
    // FileDocument protocol
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let stringData = CSVExportService.generateCSV(from: transactions)
        let data = stringData.data(using: .utf8)!
        return FileWrapper(regularFileWithContents: data)
    }
    
    // Transferable protocol
    static var transferRepresentation: some TransferRepresentation {
        // Explicitly export as a file with .csv extension
        FileRepresentation(contentType: .commaSeparatedText) { doc in
            // Create a temporary file
            let tempDir = FileManager.default.temporaryDirectory
            let fileName = "LizhiERP_Export_\(Date().formatted(date: .numeric, time: .omitted).replacingOccurrences(of: "/", with: "-")).csv"
            let tempFile = tempDir.appendingPathComponent(fileName)
            
            let csvString = CSVExportService.generateCSV(from: doc.transactions)
            try csvString.write(to: tempFile, atomically: true, encoding: .utf8)
            
            return SentTransferredFile(tempFile)
        } importing: { file in
            // We don't really support drag-and-drop import via this struct yet, just export focus
            return CSVDocument()
        }
    }
}

// Subcomponents
struct TransactionRow: View {
    let tx: Transaction
    let categories: [CategoryEntity]
    
    @Query private var assets: [AssetEntity]
    
    var icon: String {
        // Polymorphic Icon Logic
        switch tx.type {
        case .transfer:
            return "arrow.left.arrow.right"
        case .assetPurchase:
            return "chart.line.uptrend.xyaxis"
        case .income:
            return "arrow.down.circle.fill"
        case .expense:
            // 1. Match by Category Name
            if let match = categories.first(where: { $0.name == tx.categoryName }) {
                return match.icon
            }
            // 2. Match by Subcategory
            if !tx.subcategory.isEmpty, let match = categories.first(where: { $0.subcategories.contains(tx.subcategory) }) {
                return match.icon
            }
            // 3. Fallback
            return "circle"
        }
    }
    
    var iconColor: Color {
        switch tx.type {
        case .transfer:
            return .blue
        case .assetPurchase:
            return .green
        case .income:
            return .green
        case .expense:
            return Color.lizhiTextSecondary
        }
    }
    
    var body: some View {
        HStack {
            Circle()
                .fill(Color.lizhiSurface)
                .frame(width: 40, height: 40)
                .overlay(Image(systemName: icon).foregroundStyle(iconColor))
            
            VStack(alignment: .leading, spacing: 2) {
                // Polymorphic Primary Label
                Text(primaryLabel)
                    .foregroundStyle(Color.lizhiTextPrimary)
                    .font(.body)
                    .fontWeight(.bold)
                
                // Secondary Label
                if !secondaryLabel.isEmpty {
                     Text(secondaryLabel)
                        .foregroundStyle(Color.lizhiTextSecondary)
                        .font(.caption)
                        .lineLimit(1)
                }
            }
            Spacer()
            
            // Amount Display
            Text(amountText)
                .foregroundStyle(amountColor)
                .fontWeight(.medium)
                .font(.callout)
        }
        .padding(12)
        .background(Color.lizhiSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Computed Properties
    
    var primaryLabel: String {
        switch tx.type {
        case .transfer:
            // Show "FROM → TO" using asset names
            let from = assetName(for: tx.linkedAccountID) ?? tx.linkedAccountID ?? "Unknown"
            let to = assetName(for: tx.destinationAccountID) ?? tx.destinationAccountID ?? "Unknown"
            return "\(from) → \(to)"
            
        case .assetPurchase:
            // Show "BUY [Asset]"
            if let targetID = tx.targetAssetID,
               let asset = assets.first(where: { $0.id == targetID }) {
                return "BUY \(asset.ticker)"
            }
            return "Asset Purchase"
            
        case .income, .expense:
            // Standard: Subcategory > Category Name > Engine Map
            return !tx.subcategory.isEmpty ? tx.subcategory : (!tx.categoryName.isEmpty ? tx.categoryName : tx.category.rawValue)
        }
    }
    
    var secondaryLabel: String {
        switch tx.type {
        case .transfer:
            // Show note/tags if any
            return tx.contextTags.joined(separator: " • ")
            
        case .assetPurchase:
            // Show "FROM [account name], [units] units @ $[price]"
            var parts: [String] = []
            if let from = tx.linkedAccountID {
                let fromName = assetName(for: from) ?? from
                parts.append("FROM \(fromName)")
            }
            if let units = tx.units {
                let unitsFormatted = NSDecimalNumber(decimal: units).doubleValue.formatted(.number.precision(.fractionLength(2)))
                // Calculate and show price per unit if available
                if units > 0 {
                    let totalAmount = NSDecimalNumber(decimal: tx.amount).doubleValue
                    let pricePerUnit = totalAmount / NSDecimalNumber(decimal: units).doubleValue
                    parts.append("\(unitsFormatted) @ $\(pricePerUnit.formatted(.number.precision(.fractionLength(2))))")
                } else {
                    parts.append("\(unitsFormatted) units")
                }
            }
            if !tx.contextTags.isEmpty {
                parts.append(contentsOf: tx.contextTags)
            }
            return parts.joined(separator: " • ")
            
        case .income, .expense:
            var parts: [String] = []
            parts.append(contentsOf: tx.contextTags)
            
            // If no tags, show category name to be helpful
            if parts.isEmpty && !tx.subcategory.isEmpty {
                return !tx.categoryName.isEmpty ? tx.categoryName : tx.category.rawValue
            }
            
            return parts.joined(separator: " • ")
        }
    }
    
    var amountText: String {
        let symbol = CurrencyService.shared.symbol(for: tx.currency.isEmpty ? "AUD" : tx.currency)
        let amount = Double(truncating: tx.amount as NSNumber)
        
        switch tx.type {
        case .transfer:
            // Neutral display (no +/-)
            return "\(symbol)\(amount.formatted(.number.precision(.fractionLength(2))))"
        case .assetPurchase:
            // Show as negative (money out)
            return "-\(symbol)\(amount.formatted(.number.precision(.fractionLength(2))))"
        case .income:
            return "+\(symbol)\(amount.formatted(.number.precision(.fractionLength(2))))"
        case .expense:
            return "-\(symbol)\(amount.formatted(.number.precision(.fractionLength(2))))"
        }
    }
    
    var amountColor: Color {
        switch tx.type {
        case .transfer:
            return .blue
        case .assetPurchase:
            return Color.lizhiTextPrimary.opacity(0.9)
        case .income:
            return .green
        case .expense:
            return Color.lizhiTextPrimary.opacity(0.9)
        }
    }
    
    /// Look up asset name/ticker from customID
    func assetName(for customID: String?) -> String? {
        guard let id = customID else { return nil }
        // Find asset matching the customID and return its ticker (friendly name)
        return assets.first(where: { $0.customID == id })?.ticker
    }
}



