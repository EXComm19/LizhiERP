import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var transactions: [Transaction]
    @Query private var assets: [AssetEntity]
    
    @State private var showFileImporter = false
    @State private var showShareSheet = false
    @State private var exportURL: URL?
    @State private var importMessage: String?
    @State private var showImportAlert = false
    @State private var showWipeAlert = false
    
    // Currency State
    @State private var selectedBaseCurrency: String = CurrencyService.shared.baseCurrency
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Unified Header
                PageHeader(
                    title: "Settings",
                    leftAction: { dismiss() },
                    rightContent: {
                         Button {
                             dismiss()
                         } label: {
                             Text("Done").bold().foregroundStyle(.orange)
                         }
                    }
                )
                
                List {
                    Section("General") {
                        NavigationLink(destination: CategoryManagerView()) {
                            Label("Manage Categories", systemImage: "tag.fill")
                        }
                        
                        // Base Currency Selector
                        Picker(selection: $selectedBaseCurrency) {
                            ForEach(CurrencyService.shared.availableCurrencies, id: \.self) { code in
                                Text("\(CurrencyService.shared.symbol(for: code)) \(code)").tag(code)
                            }
                        } label: {
                            Label("Base Currency", systemImage: "dollarsign.circle.fill")
                        }
                        .onChange(of: selectedBaseCurrency) { _, newValue in
                            CurrencyService.shared.baseCurrency = newValue
                        }
                    }
                    
                    Section("Backup & Sync") {
                        Button {
                            exportData()
                        } label: {
                            Label("Export Data (CSV)", systemImage: "square.and.arrow.up")
                        }
                        
                        Button {
                            showFileImporter = true
                        } label: {
                            Label("Import Data (CSV)", systemImage: "square.and.arrow.down")
                        }
                    }
                    
                    Section("Data Management") {
                        Button(role: .destructive) {
                            showWipeAlert = true
                        } label: {
                            Label("Wipe All Transactions", systemImage: "trash.fill")
                        }
                    }
                    
                    Section("About") {
                        HStack {
                            Text("Version")
                            Spacer()
                            Text("1.0.0 (Alpha)")
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Section {
                        Button(role: .destructive) {
                            // Logout logic placeholder
                        } label: {
                            Text("Sign Out")
                        }
                    }
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showShareSheet) {
                if let url = exportURL {
                    ShareSheet(activityItems: [url])
                }
            }
            .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.commaSeparatedText]) { result in
                switch result {
                case .success(let url):
                    importData(from: url)
                case .failure(let error):
                    print("Import failed: \(error.localizedDescription)")
                }
            }
            .alert("Import Result", isPresented: $showImportAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(importMessage ?? "Unknown result")
            }
            .alert("Wipe All Data", isPresented: $showWipeAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete Everything", role: .destructive) {
                     wipeAllTransactions()
                }
            } message: {
                Text("This action cannot be undone. All transaction records will be permanently deleted.")
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
    
    func wipeAllTransactions() {
        do {
            try modelContext.delete(model: Transaction.self)
            try modelContext.save()
            print("Settings: All transactions wiped.")
            
            // Trigger Engine to reset Assets (recalculate with 0 transactions)
            let container = modelContext.container
            Task {
                let engine = FinancialEngine(modelContainer: container)
                await engine.recalculateAssetBalances()
            }
            
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        } catch {
            print("Wipe failed: \(error)")
        }
    }

    func exportData() {
        let csv = CSVExportService.generateCSV(from: transactions, assets: assets)
        let fileName = "LizhiERP_Export_\(Date().formatted(date: .numeric, time: .omitted).replacingOccurrences(of: "/", with: "-")).csv"
        
        if let path = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let fileURL = path.appendingPathComponent(fileName)
            do {
                // Excel for Mac doesn't auto-detect UTF-8, it needs a BOM to recognize it
                // Numbers works fine without BOM, but Excel requires it
                let bom = Data([0xEF, 0xBB, 0xBF]) // UTF-8 BOM
                var fileData = bom
                
                if let csvData = csv.data(using: .utf8) {
                    fileData.append(csvData)
                    try fileData.write(to: fileURL, options: .atomic)
                    exportURL = fileURL
                    showShareSheet = true
                } else {
                    print("Failed to encode CSV string to UTF-8")
                }
            } catch {
                print("Export failed: \(error)")
            }
        }
    }
    
    @State private var isImporting = false
    @State private var importProgress: Double = 0.0
    
    func importData(from url: URL) {
        isImporting = true
        importProgress = 0.0
        
        // Start accessing security scoped resource
        guard url.startAccessingSecurityScopedResource() else {
            isImporting = false
            return
        }
        
        // Copy to temporary file to avoid locking issues
        // and handle async processing safely
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
            isImporting = false
            return
        }
        
        // We can stop accessing the original URL now that we have a copy
        url.stopAccessingSecurityScopedResource()
        
        Task {
            do {
                // Read from temp file
                var content = ""
                // Try UTF-8 first
                if let str = try? String(contentsOf: tempFile, encoding: .utf8) {
                    content = str
                } else {
                    // Fallback to ASCII/MacOSRoman if needed, or just try generic
                    content = try String(contentsOf: tempFile)
                }
                
                // Strip UTF-8 BOM if present (important for round-trip with our export)
                if content.hasPrefix("\u{FEFF}") {
                    content = String(content.dropFirst())
                }
                
                // Parsing phase status
                await MainActor.run { importProgress = 0.1 }
                
                let result = await CSVImportService.processCSV(content: content)
                
                // Cleanup temp file
                try? FileManager.default.removeItem(at: tempFile)
                
                // Save to context on MainActor with batching
                await MainActor.run {
                    var count = 0
                    let total = Double(result.transactions.count)
                    
                    // We can't easily yield within MainActor.run block in a loop efficiently without breaking context?
                    // SwiftData context is main thread bound.
                    // To keep UI responsive, we process in chunks and yield.
                    
                    Task {
                        for tx in result.transactions {
                            modelContext.insert(tx)
                            count += 1
                            
                            // Yield every 50 items to let UI update (spinner animate)
                            if count % 50 == 0 {
                                importProgress = 0.1 + (0.9 * (Double(count) / total))
                                try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
                            }
                        }
                        
                        try? modelContext.save() // Ensure data is persisted for background access
                        
                        // Recalculate asset balances after import
                        let container = modelContext.container
                        let engine = FinancialEngine(modelContainer: container)
                        await engine.recalculateAssetBalances()
                        
                        importMessage = "Imported \(result.transactions.count) records.\nErrors: \(result.errors.count)"
                        showImportAlert = true
                        isImporting = false
                        importProgress = 1.0
                    }
                }
            } catch {
                print("Failed to read file: \(error)")
                await MainActor.run { isImporting = false }
            }
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    var activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
