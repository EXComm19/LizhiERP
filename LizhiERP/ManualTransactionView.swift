import SwiftUI
import SwiftData

struct ManualTransactionView: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var isPresented: Bool
    
    var transactionToEdit: Transaction?
    
    // Form State
    @State private var inputAmount: Double?
    @State private var selectedType: TransactionType = .expense
    
    // Selection
    // Dynamic Categories
    @Query(filter: #Predicate<CategoryEntity> { $0.type == "Expense" }, sort: \CategoryEntity.sortOrder) private var expenseCategories: [CategoryEntity]
    @Query(filter: #Predicate<CategoryEntity> { $0.type == "Income" }, sort: \CategoryEntity.sortOrder) private var incomeCategories: [CategoryEntity]
    
    // Selection
    @State private var selectedCategory: CategoryEntity?
    @State private var selectedSubcategory: String = ""
    
    @State private var note: String = ""
    @State private var date: Date = Date()
    @State private var showDatePicker = false
    
    // Focus State
    @FocusState private var isAmountFocused: Bool
    
    // Computed Categories
    var currentCategories: [CategoryEntity] {
        switch selectedType {
        case .expense: return expenseCategories
        case .income: return incomeCategories
        case .transfer: return [] // Blank for now per request
        case .assetPurchase: return [] // Blank
        }
    }
    
    init(isPresented: Binding<Bool>, transactionToEdit: Transaction? = nil) {
        self._isPresented = isPresented
        self.transactionToEdit = transactionToEdit
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            Color(hex: "111111").ignoresSafeArea()
            
            VStack(spacing: 24) {
                // 1. Header
                header
                
                // 2. Segmented Picker
                segmentedControl
                
                // 3. Value & Date Row
                HStack(spacing: 12) {
                    HStack {
                        Text("$")
                            .foregroundStyle(.gray)
                        TextField("0.00", value: $inputAmount, format: .number.precision(.fractionLength(2)))
                            .keyboardType(.decimalPad)
                            .focused($isAmountFocused)
                            .foregroundStyle(.white)
                            .font(.system(size: 20, weight: .bold, design: .monospaced))
                    }
                    .padding()
                    .frame(height: 56)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.orange.opacity(0.8), lineWidth: 1)
                            .background(Color(hex: "1A1A1A").cornerRadius(12))
                    )
                    
                    Button { showDatePicker = true } label: {
                        Text(date.formatted(.dateTime.year().month(.twoDigits).day(.twoDigits)))
                            .font(.system(size: 16, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white)
                            .padding()
                            .frame(height: 56)
                            .frame(maxWidth: .infinity)
                            .background(Color(hex: "2A2A2A"))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .frame(width: 140)
                }
                .padding(.horizontal)
                
                // 4. Category & Subcategory Section
                if selectedType != .transfer {
                    VStack(alignment: .leading, spacing: 16) {
                        // Categories
                        VStack(alignment: .leading, spacing: 8) {
                            Text("CATEGORY")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundStyle(.gray)
                                .padding(.horizontal)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 16) {
                                    ForEach(currentCategories) { cat in
                                        categoryItem(cat)
                                    }
                                    
                                    // Empty State or Manage
                                    if currentCategories.isEmpty {
                                        Text("No categories found. Go to Settings to add.")
                                            .font(.caption)
                                            .foregroundStyle(.gray)
                                            .padding(.horizontal)
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                        
                        // Subcategories (only if category selected)
                        if let category = selectedCategory, !category.subcategories.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("SUBCATEGORY")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.gray)
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
                            .padding(.top, 4) // Add a little breathing room
                            .transition(.opacity.animation(.easeInOut(duration: 0.2))) // Smoother fade
                        }
                    }
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: selectedCategory)
                } // End if !transfer
  
                
                // 5. Details / Note
                VStack(alignment: .leading, spacing: 8) {
                    Text("NOTE")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.gray)
                        .padding(.horizontal)
                    
                    TextField("Description", text: $note)
                        .padding()
                        .frame(height: 56)
                        .background(Color(hex: "2A2A2A"))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(.white)
                        .padding(.horizontal)
                }
                
                Spacer()
                
                // 6. Action Button
                Button(action: saveTransaction) {
                    Text(transactionToEdit == nil ? "Add Record" : "Update Record")
                        .font(.headline)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .padding(.horizontal)
                .padding(.bottom, 40) // Safe Area Bottom
            }
            .padding(.top, 24) // Add internal padding relative to sheet
        }
        .onAppear {
            if let tx = transactionToEdit {
                // Pre-fill for editing
                inputAmount = NSDecimalNumber(decimal: tx.amount).doubleValue
                selectedType = tx.type
                date = tx.date
                selectedSubcategory = tx.subcategory
                note = tx.contextTags.first ?? "" // Assuming first tag is note for now
                
                // Find matching CategoryEntity
                // Since we don't store CategoryEntity ID in Transaction (yet), we match by mappedCategory and attempt to find a name match if possible
                // or just rely on user re-selecting.
                // Ideally Transaction should store `categoryEntityName` or ID.
                // For now, we only have `category` (enum).
                // Let's try to match by enum.
                let list = (tx.type == .expense ? expenseCategories : incomeCategories)
                if let match = list.first(where: { $0.subcategories.contains(tx.subcategory) }) {
                     selectedCategory = match
                } else if let match = list.first(where: { $0.mappedCategory == tx.category }) {
                     selectedCategory = match
                }
                
            } else {
                isAmountFocused = true
                // Default select first available
                if let first = currentCategories.first {
                    selectedCategory = first
                    selectedSubcategory = first.subcategories.first ?? ""
                }
            }
        }
        .onChange(of: selectedType) { _, newType in
             // Reset selection on type change
             if let first = currentCategories.first {
                 selectedCategory = first
                 selectedSubcategory = first.subcategories.first ?? ""
             } else {
                 selectedCategory = nil
                 selectedSubcategory = ""
             }
        }
        .sheet(isPresented: $showDatePicker) {
            DatePicker("Select Date", selection: $date, displayedComponents: [.date])
                .datePickerStyle(.graphical)
                .presentationDetents([.medium])
        }
    }
    
    // MARK: - Components UI
    
    var header: some View {
        HStack {
            Text(transactionToEdit == nil ? "New Record" : "Edit Record")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.white)
            Spacer()
            Button { isPresented = false } label: {
                Image(systemName: "xmark")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(8)
                    .background(Color(hex: "2A2A2A"))
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal)
        .padding(.top, 20) // Extra padding for sheet top edge
    }
    
    var segmentedControl: some View {
        HStack(spacing: 0) {
            segmentButton("Expense", .expense)
            Divider().background(Color.white.opacity(0.1))
            segmentButton("Income", .income)
            Divider().background(Color.white.opacity(0.1))
            segmentButton("Move Money", .transfer)
        }
        .frame(height: 44)
        .background(Color(hex: "2A2A2A"))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }
    
    func segmentButton(_ title: String, _ type: TransactionType) -> some View {
        Button {
            withAnimation(.spring()) { selectedType = type }
            triggerHaptic(.glassTap)
        } label: {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(selectedType == type ? .white : .gray)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(selectedType == type ? Color(hex: "3A3A3A") : Color.clear)
        }
    }
    
    func categoryItem(_ cat: CategoryEntity) -> some View {
        // Smaller icons as requested
        Button {
            selectedCategory = cat
            // Default select first subcategory
            selectedSubcategory = cat.subcategories.first ?? ""
            triggerHaptic(.glassTap)
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(selectedCategory?.persistentModelID == cat.persistentModelID ? Color.blue.opacity(0.2) : Color(hex: "2A2A2A"))
                        .frame(width: 48, height: 48) // Smaller than previous 56
                    
                    Image(systemName: cat.icon)
                        .font(.body) // Smaller font
                        .foregroundStyle(selectedCategory?.persistentModelID == cat.persistentModelID ? .blue : .gray)
                }
                .overlay(
                    Circle()
                        .stroke(selectedCategory?.persistentModelID == cat.persistentModelID ? Color.gray.opacity(0.5) : Color.clear, lineWidth: 1)
                )
                
                Text(cat.name)
                    .font(.caption2)
                    .foregroundStyle(selectedCategory?.persistentModelID == cat.persistentModelID ? .white : .gray)
            }
        }
    }
    
    func subcategoryItem(_ name: String) -> some View {
        Button {
            selectedSubcategory = name
            triggerHaptic(.glassTap)
        } label: {
            Text(name)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(selectedSubcategory == name ? Color.white : Color(hex: "2A2A2A"))
                .foregroundStyle(selectedSubcategory == name ? .black : .gray)
                .clipShape(Capsule())
        }
    }
    
    // MARK: - Logic
    
    func saveTransaction() {
        guard let amount = inputAmount, amount > 0 else { return }
        
        // Use selected options or fallback
        let subcat = selectedSubcategory.isEmpty ? (selectedCategory?.name ?? "") : selectedSubcategory
        let mappedCat = selectedCategory?.mappedCategory ?? .survival
        
        if let tx = transactionToEdit {
            // Update Existing
            tx.amount = Decimal(amount)
            tx.type = selectedType
            tx.category = mappedCat
            tx.date = date
            tx.subcategory = subcat
            tx.contextTags = note.isEmpty ? [] : [note]
        } else {
            // Create New
            let newTx = Transaction(
                amount: Decimal(amount),
                type: selectedType,
                category: mappedCat,
                source: .spending,
                date: date,
                contextTags: [],
                subcategory: subcat
            )
            if !note.isEmpty {
                newTx.contextTags.append(note)
            }
            modelContext.insert(newTx)
        }
        
        triggerHaptic(.hustle)
        isPresented = false
    }
}
