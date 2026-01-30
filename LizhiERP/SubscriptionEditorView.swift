import SwiftUI
import SwiftData

struct SubscriptionEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var isPresented: Bool
    
    var subscriptionToEdit: Subscription? // Optional binding if passed
    
    @State private var name: String = ""
    @State private var amount: Double?
    @State private var selectedCycle: String = "Monthly"
    @State private var firstBillDate: Date = Date()
    @State private var selectedIcon: String = "tv"
    
    @State private var currency: String = CurrencyService.shared.baseCurrency
    
    @State private var showDatePicker = false
    @State private var weekdaysOnly = false
    
    @FocusState private var isNameFocused: Bool
    
    let icons = ["tv", "music.note", "cloud.fill", "cart.fill", "bolt.fill", "iphone"]
    
    init(isPresented: Binding<Bool>, subscriptionToEdit: Subscription? = nil) {
        self._isPresented = isPresented
        self.subscriptionToEdit = subscriptionToEdit
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            Color.lizhiBackground.ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Header
                HStack {
                    Text(subscriptionToEdit == nil ? "New Subscription" : "Edit Subscription")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.lizhiTextPrimary)
                    Spacer()
                    Button {
                        isPresented = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Color.lizhiTextSecondary)
                    }
                }
                .padding(.horizontal)
                
                // Name Input
                VStack(alignment: .leading, spacing: 8) {
                    Text("NAME")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.lizhiTextSecondary)
                    
                    TextField("e.g. Netflix", text: $name)
                        .padding()
                        .frame(height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.blue, lineWidth: 1)
                                .background(Color.lizhiSurface.cornerRadius(12))
                        )
                        .foregroundStyle(Color.lizhiTextPrimary)
                        .focused($isNameFocused)
                }
                .padding(.horizontal)
                
                // Icon Selector
                VStack(alignment: .leading, spacing: 12) {
                    Text("ICON")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.lizhiTextSecondary)
                    
                    HStack(spacing: 16) {
                        ForEach(icons, id: \.self) { icon in
                            Button {
                                selectedIcon = icon
                                triggerHaptic(.glassTap)
                            } label: {
                                Circle()
                                    .fill(selectedIcon == icon ? Color.lizhiTextPrimary : Color.lizhiSurface)
                                    .frame(width: 50, height: 50)
                                    .overlay(
                                        Image(systemName: icon)
                                            .foregroundStyle(selectedIcon == icon ? Color.lizhiBackground : Color.lizhiTextSecondary)
                                    )
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Amount & Cycle
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("AMOUNT")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.lizhiTextSecondary)
                        
                        HStack {
                            // Currency Picker
                            Picker("", selection: $currency) {
                                ForEach(CurrencyService.shared.availableCurrencies, id: \.self) { code in
                                    Text(CurrencyService.shared.symbol(for: code)).tag(code)
                                }
                            }
                            .tint(Color.lizhiTextSecondary)
                            .labelsHidden()
                            
                            TextField("0.00", value: $amount, format: .number.precision(.fractionLength(2)))
                                .keyboardType(.decimalPad)
                                .foregroundStyle(Color.lizhiTextPrimary)
                        }
                        .padding()
                        .frame(height: 56)
                        .background(Color.lizhiSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("CYCLE")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.lizhiTextSecondary)
                        
                        Menu {
                            Button("Monthly") { selectedCycle = "Monthly" }
                            Button("Yearly") { selectedCycle = "Yearly" }
                            Button("Weekly") { selectedCycle = "Weekly" }
                        } label: {
                            HStack {
                                Text(selectedCycle)
                                    .foregroundStyle(Color.lizhiTextPrimary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                                Spacer()
                                Image(systemName: "chevron.up.chevron.down")
                                    .foregroundStyle(Color.lizhiTextSecondary)
                            }
                            .padding()
                            .frame(height: 56)
                            .background(Color.lizhiSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
                .padding(.horizontal)
                
                // First Bill Date + Weekdays Only
                VStack(alignment: .leading, spacing: 8) {
                    Text("FIRST BILL")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.lizhiTextSecondary)
                    
                    HStack(spacing: 12) {
                        Button {
                            showDatePicker = true
                        } label: {
                            HStack {
                                Text(firstBillDate.formatted(date: .numeric, time: .omitted))
                                    .foregroundStyle(Color.lizhiTextPrimary)
                                Spacer()
                                Image(systemName: "calendar")
                                    .foregroundStyle(Color.lizhiTextSecondary)
                            }
                            .padding()
                            .frame(height: 56)
                            .background(Color.lizhiSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        
                        Button {
                            weekdaysOnly.toggle()
                            triggerHaptic(.glassTap)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: weekdaysOnly ? "checkmark.square.fill" : "square")
                                    .foregroundStyle(weekdaysOnly ? Color.blue : Color.lizhiTextSecondary)
                                Text("Weekdays\nOnly")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundStyle(Color.lizhiTextPrimary)
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.8)
                            }
                            .padding(.horizontal, 12)
                            .frame(height: 56)
                            .background(Color.lizhiSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Create Button
                Button(action: saveSubscription) {
                    Text(subscriptionToEdit == nil ? "Create Subscription" : "Update Subscription")
                        .font(.headline)
                        .foregroundStyle(Color.lizhiBackground)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.lizhiTextPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .padding(.top, 24)
        }
        .onAppear {
            if let sub = subscriptionToEdit {
                name = sub.name
                amount = NSDecimalNumber(decimal: sub.amount).doubleValue
                selectedCycle = sub.cycle
                firstBillDate = sub.firstBillDate
                selectedIcon = sub.icon
                currency = sub.currency
            } else {
                isNameFocused = true
            }
        }
        .sheet(isPresented: $showDatePicker) {
            DatePicker("Select Date", selection: $firstBillDate, displayedComponents: [.date])
                .datePickerStyle(.graphical)
                .presentationDetents([.medium])
        }
    }
    
    func saveSubscription() {
        print("DEBUG: Attempting to save subscription. Name: \(name), Amount: \(String(describing: amount))")
        
        guard let amount = amount, !name.isEmpty else {
            print("DEBUG: Validation failed. Name empty or Amount nil")
            return
        }
        
        if let sub = subscriptionToEdit {
            // Update existing
            sub.name = name
            sub.amount = Decimal(amount)
            sub.cycle = selectedCycle
            sub.firstBillDate = firstBillDate
            sub.icon = selectedIcon
            sub.currency = currency
            print("DEBUG: Updating existing subscription: \(sub.name)")
        } else {
            // Create new
            let sub = Subscription(name: name, amount: Decimal(amount), cycle: selectedCycle, firstBillDate: firstBillDate, icon: selectedIcon, currency: currency)
            modelContext.insert(sub)
            print("DEBUG: Inserting new subscription: \(sub.name)")
        }
        
        do {
            try modelContext.save()
            print("DEBUG: Context saved successfully")
        } catch {
            print("DEBUG: Context save failed: \(error)")
        }
        
        triggerHaptic(.hustle)
        isPresented = false
    }
}
