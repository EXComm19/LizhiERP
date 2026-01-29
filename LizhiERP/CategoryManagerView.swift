import SwiftUI
import SwiftData

struct CategoryManagerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<CategoryEntity> { $0.type == "Expense" }, sort: \CategoryEntity.sortOrder) private var expenseCategories: [CategoryEntity]
    @Query(filter: #Predicate<CategoryEntity> { $0.type == "Income" }, sort: \CategoryEntity.sortOrder) private var incomeCategories: [CategoryEntity]
    
    @State private var selectedTab: TransactionType = .expense
    @State private var showEditor = false
    @State private var categoryToEdit: CategoryEntity?
    
    var body: some View {
        VStack(spacing: 0) {
            // Unified Header
            PageHeader(
                title: "Categories",
                leftAction: { dismiss() },
                rightContent: {
                    HStack(spacing: 12) {
                        Button {
                            DataManager.shared.seedCategories(context: modelContext)
                            triggerHaptic(.hustle)
                        } label: {
                            Image(systemName: "arrow.triangle.2.circlepath") // Sync icon
                                .standardButtonStyle()
                        }
                        
                        Button {
                            categoryToEdit = nil
                            showEditor = true
                        } label: {
                            Image(systemName: "plus")
                                .standardButtonStyle()
                        }
                    }
                }
            )
            
            VStack {
                Picker("Type", selection: $selectedTab) {
                    Text("Expense").tag(TransactionType.expense)
                    Text("Income").tag(TransactionType.income)
                }
                .pickerStyle(.segmented)
                .padding()
                
                List {
                    ForEach(selectedTab == .expense ? expenseCategories : incomeCategories) { cat in
                        Button {
                            categoryToEdit = cat
                            showEditor = true
                        } label: {
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(Color(hex: "2A2A2A"))
                                    .frame(width: 36, height: 36)
                                    .overlay(Image(systemName: cat.icon).foregroundStyle(.blue))
                                
                                VStack(alignment: .leading) {
                                    Text(cat.name)
                                        .font(.headline)
                                    Text(cat.subcategories.joined(separator: ", "))
                                        .font(.caption)
                                        .foregroundStyle(.gray)
                                        .lineLimit(1)
                                }
                            }
                        }
                        .swipeActions {
                            Button(role: .destructive) {
                                modelContext.delete(cat)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showEditor) {
            CategoryEditorView(isPresented: $showEditor, categoryToEdit: categoryToEdit, defaultType: selectedTab)
        }
    }
}

struct CategoryEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var isPresented: Bool
    
    var categoryToEdit: CategoryEntity?
    var defaultType: TransactionType
    
    @State private var name: String = ""
    @State private var selectedIcon: String = "tag.fill"
    @State private var mappedCategory: TransactionCategory = .survival
    @State private var subcategories: [String] = []
    @State private var newSubcategory: String = ""
    
    let availableIcons = ["cart.fill", "fork.knife", "car.fill", "house.fill", "gamecontroller.fill", "airplane", "cross.case.fill", "book.fill", "bag.fill", "tag.fill", "bolt.fill", "dollarsign.circle.fill", "chart.line.uptrend.xyaxis", "gift.fill"]
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Info") {
                    TextField("Category Name", text: $name)
                    
                    Picker("Engine Map", selection: $mappedCategory) {
                        ForEach(TransactionCategory.allCases, id: \.self) { cat in
                            Text(cat.rawValue).tag(cat)
                        }
                    }
                }
                
                Section("Icon") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(availableIcons, id: \.self) { icon in
                                Button {
                                    selectedIcon = icon
                                } label: {
                                    Circle()
                                        .fill(selectedIcon == icon ? Color.blue : Color(hex: "2A2A2A"))
                                        .frame(width: 44, height: 44)
                                        .overlay(Image(systemName: icon).foregroundStyle(selectedIcon == icon ? .white : .gray))
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
                
                Section("Subcategories") {
                    HStack {
                        TextField("New Subcategory", text: $newSubcategory)
                            .onSubmit { addSubcategory() }
                        
                        Button {
                            addSubcategory()
                        } label: {
                            Image(systemName: "plus.circle.fill")
                        }
                        .disabled(newSubcategory.isEmpty)
                    }
                    
                    ForEach(subcategories, id: \.self) { sub in
                        Text(sub)
                    }
                    .onDelete { indexSet in
                        subcategories.remove(atOffsets: indexSet)
                    }
                }
            }
            .navigationTitle(categoryToEdit == nil ? "New Category" : "Edit Category")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(name.isEmpty)
                }
            }
            .onAppear {
                if let cat = categoryToEdit {
                    name = cat.name
                    selectedIcon = cat.icon
                    mappedCategory = cat.mappedCategory
                    subcategories = cat.subcategories
                }
            }
        }
    }
    
    func addSubcategory() {
        guard !newSubcategory.isEmpty else { return }
        subcategories.append(newSubcategory)
        newSubcategory = ""
    }
    
    func save() {
        if let cat = categoryToEdit {
            cat.name = name
            cat.icon = selectedIcon
            cat.mappedCategory = mappedCategory
            cat.subcategories = subcategories
        } else {
            let newCat = CategoryEntity(name: name, icon: selectedIcon, type: defaultType, mappedCategory: mappedCategory, subcategories: subcategories)
            modelContext.insert(newCat)
        }
        isPresented = false
    }
}
