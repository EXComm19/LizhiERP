import SwiftUI
import SwiftData

struct LedgerView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Transaction.date, order: .reverse) private var allTransactions: [Transaction]
    
    // Search
    @State private var searchText: String = ""
    
    // Sort & Filters
    @State private var isFilterOpen: Bool = false
    @State private var selectedType: TransactionType? = nil // Nil = All
    @State private var selectedMonth: Date? = nil // Nil = All Time
    @State private var selectedCategory: TransactionCategory? = nil
    
    // Filtering Logic
    var filteredTransactions: [Transaction] {
        allTransactions.filter { tx in
            // Search Text
            let matchSearch = searchText.isEmpty || 
                tx.subcategory.localizedCaseInsensitiveContains(searchText) ||
                tx.category.rawValue.localizedCaseInsensitiveContains(searchText) ||
                tx.contextTags.contains { $0.localizedCaseInsensitiveContains(searchText) }
            
            // Type Filter
            let matchType = selectedType == nil || tx.type == selectedType
            
            // Category Filter
            let matchCategory = selectedCategory == nil || tx.category == selectedCategory
            
            // Month Filter
            let matchMonth: Bool
            if let month = selectedMonth {
                let calendars = Calendar.current
                matchMonth = calendars.isDate(tx.date, equalTo: month, toGranularity: .month)
            } else {
                matchMonth = true
            }
            
            return matchSearch && matchType && matchCategory && matchMonth
        }
    }
    
    // Grouping
    var groupedTransactions: [(Date, [Transaction])] {
        let grouped = Dictionary(grouping: filteredTransactions) { tx in
            Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: tx.date))!
        }
        return grouped.sorted { $0.key > $1.key }
    }
    
    // Helper for Month Filter options
    var availableMonths: [Date] {
        let dates = allTransactions.map { Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: $0.date))! }
        return Array(Set(dates)).sorted(by: >)
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Nav Bar
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "arrow.left")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .padding()
                            .background(Color(hex: "1A1A1A"))
                            .clipShape(Circle())
                    }
                    Spacer()
                    Text("Ledger")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Spacer()
                    
                    // Import/Export Buttons
                    HStack(spacing: 8) {
                        // Export
                        ShareLink(item: csvFile, preview: SharePreview("LizhiERP_Export.csv")) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.body)
                                .foregroundStyle(.white)
                                .padding(10)
                                .background(Color(hex: "1A1A1A"))
                                .clipShape(Circle())
                        }
                        
                        // Import
                        Button {
                           showImporter = true
                        } label: {
                            Image(systemName: "square.and.arrow.down")
                                .font(.body)
                                .foregroundStyle(.white)
                                .padding(10)
                                .background(Color(hex: "1A1A1A"))
                                .clipShape(Circle())
                        }
                    }
                    .padding(.trailing, 4)
                    
                    // Filter Toggle Button
                    Button {
                        withAnimation { isFilterOpen.toggle() }
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                            .font(.title2)
                            .foregroundStyle(isFilterActive ? .orange : .white)
                            .padding()
                            .background(Color(hex: "1A1A1A"))
                            .clipShape(Circle())
                            .overlay(
                                Circle().stroke(isFilterActive ? Color.orange : Color.clear, lineWidth: 1)
                            )
                    }
                }
                .padding()
                
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.gray)
                    TextField("Search transactions...", text: $searchText)
                        .foregroundStyle(.white)
                        .tint(.orange)
                    if !searchText.isEmpty {
                        Button { searchText = "" } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(.gray)
                        }
                    }
                }
                .padding()
                .background(Color(hex: "1A1A1A"))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
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
                        
                        // Month Scroll
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                Button { selectedMonth = nil } label: {
                                    Text("All Time")
                                        .filterChip(isSelected: selectedMonth == nil)
                                }
                                ForEach(availableMonths, id: \.self) { date in
                                    Button { selectedMonth = date } label: {
                                        Text(date.formatted(.dateTime.month().year()))
                                            .filterChip(isSelected: selectedMonth == date)
                                    }
                                }
                            }
                        }
                        
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
                    .padding()
                    .background(Color(hex: "111111"))
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                // List
                List {
                    ForEach(groupedTransactions, id: \.0) { (month, txs) in
                        Section {
                            ForEach(txs) { tx in
                                TransactionRow(tx: tx)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        selectedTransaction = tx
                                        showEditor = true
                                        triggerHaptic(.glassTap)
                                    }
                                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
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
                            Text(month.formatted(.dateTime.month(.wide).year()))
                                .font(.callout)
                                .fontWeight(.bold)
                                .foregroundStyle(.orange)
                                .listRowInsets(EdgeInsets(top: 16, leading: 16, bottom: 8, trailing: 16))
                        }
                    }
                    .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .sheet(isPresented: $showEditor) {
            ManualTransactionView(isPresented: $showEditor, transactionToEdit: selectedTransaction)
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
    }
    
    @Environment(\.modelContext) private var modelContext
    
    // Import/Export
    @State private var showImporter = false
    
    // Editing
    @State private var selectedTransaction: Transaction? = nil
    @State private var showEditor = false

    var isFilterActive: Bool {
        selectedType != nil || selectedMonth != nil || selectedCategory != nil
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
        // Run in background to avoid blocking thread
        Task {
            do {
                if url.startAccessingSecurityScopedResource() {
                    defer { url.stopAccessingSecurityScopedResource() }
                    
                    let data = try String(contentsOf: url, encoding: .utf8)
                    let rows = data.components(separatedBy: "\n")
                    var count = 0
                    
                    for row in rows.dropFirst() { // Skip header
                        let columns = row.components(separatedBy: ",")
                        if columns.count >= 6 {
                            // Simple parsing
                            // 0: Date, 1: Type, 2: Amount, 3: Category, 4: Sub, 5: Note
                            let dateStr = columns[0]
                            let typeStr = columns[1]
                            let amountStr = columns[2]
                            let catStr = columns[3] // We ignore this as we rely on UI category map usually, or default
                            let subStr = columns[4]
                            let noteStr = columns[5]
                            
                            // Date
                            let formatter = ISO8601DateFormatter()
                            let date = formatter.date(from: dateStr) ?? Date()
                            
                            // Type
                            let type: TransactionType = (typeStr == "Income") ? .income : .expense
                            
                            // Amount (Simple cast, better to use Decimal)
                            let amount = Decimal(string: amountStr) ?? 0
                            
                            let newTx = Transaction(
                                amount: amount,
                                type: type,
                                category: .uncategorized, // Simplified for import
                                source: .spending, // Default to spending instead of .manual
                                date: date,
                                contextTags: [noteStr].filter { !$0.isEmpty },
                                subcategory: subStr
                            )
                            modelContext.insert(newTx)
                            count += 1
                        }
                    }
                    print("Imported \(count) transactions")
                    triggerHaptic(.hustle)
                }
            } catch {
                print("Import failed: \(error)")
            }
        }
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
        // We handle import via standard file reading, this is for opening files as a document
        self.transactions = []
    }
    
    // FileDocument protocol
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = generateCSVData()
        return FileWrapper(regularFileWithContents: data)
    }
    
    // Transferable protocol
    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(contentType: .commaSeparatedText) { doc in
            doc.generateCSVData()
        } importing: { data in
            CSVDocument() // Dummy import for Transferable, actual import is handled via fileImporter
        }
    }
    
    func generateCSVData() -> Data {
        let headers = "Date,Type,Amount,Category,Subcategory,Note\n"
        let rows = transactions.map { tx in
            let date = tx.date.formatted(.iso8601)
            let type = tx.type == .expense ? "Expense" : "Income"
            let amount = String(describing: tx.amount)
            let cat = tx.category.rawValue
            let sub = tx.subcategory
            let note = tx.contextTags.joined(separator: "; ").replacingOccurrences(of: ",", with: " ") // Escape commas
            return "\(date),\(type),\(amount),\(cat),\(sub),\(note)"
        }.joined(separator: "\n")
        
        let csv = headers + rows
        return csv.data(using: .utf8)!
    }
}

// Subcomponents
struct TransactionRow: View {
    let tx: Transaction
    
    var body: some View {
        HStack {
            Circle()
                .fill(Color(hex: "2A2A2A"))
                .frame(width: 40, height: 40)
                .overlay(Text(String(tx.category.rawValue.prefix(1))).font(.caption).bold().foregroundStyle(.gray))
            
            VStack(alignment: .leading) {
                Text(tx.subcategory.isEmpty ? tx.category.rawValue : tx.subcategory)
                    .foregroundStyle(.white)
                    .font(.body)
                Text(tx.date.formatted(date: .numeric, time: .omitted))
                    .foregroundStyle(.gray)
                    .font(.caption)
            }
            Spacer()
            Text("\(tx.type == .expense ? "-" : "+")$\(Double(truncating: tx.amount as NSNumber), specifier: "%.2f")")
                .foregroundStyle(tx.type == .expense ? .white : .green)
                .fontWeight(.medium)
        }
        .padding()
        .background(Color(hex: "1A1A1A"))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

extension View {
    func filterChip(isSelected: Bool) -> some View {
        self
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.orange : Color(hex: "2A2A2A"))
            .foregroundStyle(isSelected ? .black : .white)
            .clipShape(Capsule())
    }
}
