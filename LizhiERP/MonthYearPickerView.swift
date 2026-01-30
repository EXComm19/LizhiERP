import SwiftUI

/// Custom Month/Year Picker with wheel-style layout
/// Matches the reference design with side-by-side year and month wheels
struct MonthYearPickerView: View {
    @Binding var selectedDate: Date
    @Binding var isPresented: Bool
    
    @State private var selectedYear: Int
    @State private var selectedMonth: Int
    
    private let calendar = Calendar.current
    private let years: [Int]
    private let months = Calendar.current.monthSymbols // Full month names
    
    init(selectedDate: Binding<Date>, isPresented: Binding<Bool>) {
        self._selectedDate = selectedDate
        self._isPresented = isPresented
        
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: selectedDate.wrappedValue)
        let currentMonth = calendar.component(.month, from: selectedDate.wrappedValue)
        
        self._selectedYear = State(initialValue: currentYear)
        self._selectedMonth = State(initialValue: currentMonth)
        
        // Generate years range: current year - 10 to current year + 5
        let thisYear = calendar.component(.year, from: Date())
        self.years = Array((thisYear - 10)...(thisYear + 5))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .foregroundStyle(Color.lizhiTextSecondary)
                
                Spacer()
                
                Text("Select Period")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.lizhiTextPrimary)
                
                Spacer()
                
                Button("Done") {
                    applySelection()
                    isPresented = false
                }
                .fontWeight(.semibold)
                .foregroundStyle(.blue)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            
            // Picker Wheels
            HStack(spacing: 16) {
                // Year Wheel
                WheelColumn(
                    items: years.map { String($0) },
                    selectedIndex: Binding(
                        get: { years.firstIndex(of: selectedYear) ?? 0 },
                        set: { selectedYear = years[$0] }
                    )
                )
                
                // Month Wheel
                WheelColumn(
                    items: months,
                    selectedIndex: Binding(
                        get: { selectedMonth - 1 },
                        set: { selectedMonth = $0 + 1 }
                    )
                )
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }

        .background(Color.clear)
        .presentationBackground {
            Rectangle()
                .fill(.thinMaterial)
                .overlay(
                    LinearGradient(
                        colors: [.white.opacity(0.1), .white.opacity(0.02)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
    }
    
    private func applySelection() {
        var components = DateComponents()
        components.year = selectedYear
        components.month = selectedMonth
        components.day = 1
        
        if let newDate = calendar.date(from: components) {
            selectedDate = newDate
        }
    }
}

// MARK: - Wheel Column Component
struct WheelColumn: View {
    let items: [String]
    @Binding var selectedIndex: Int
    
    private let itemHeight: CGFloat = 44
    private let visibleItems: Int = 5
    
    var body: some View {
        GeometryReader { geometry in
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        // Top padding
                        Color.clear.frame(height: itemHeight * 2)
                        
                        ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                            Text(item)
                                .font(.title3)
                                .fontWeight(selectedIndex == index ? .bold : .regular)
                                .foregroundStyle(selectedIndex == index ? .white : Color.lizhiTextSecondary)
                                .frame(height: itemHeight)
                                .frame(maxWidth: .infinity)
                                .background(
                                    Group {
                                        if selectedIndex == index {
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(Color(hex: "2C3E50"))
                                        }
                                    }
                                )
                                .id(index)
                                .onTapGesture {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        selectedIndex = index
                                        proxy.scrollTo(index, anchor: .center)
                                    }
                                    triggerHaptic(.glassTap)
                                }
                        }
                        
                        // Bottom padding
                        Color.clear.frame(height: itemHeight * 2)
                    }
                }
                .onAppear {
                    proxy.scrollTo(selectedIndex, anchor: .center)
                }
                .onChange(of: selectedIndex) { _, newValue in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        proxy.scrollTo(newValue, anchor: .center)
                    }
                }
            }
        }
        .frame(height: itemHeight * CGFloat(visibleItems))
        .mask(
            LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .black, location: 0.25),
                    .init(color: .black, location: 0.75),
                    .init(color: .clear, location: 1)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}

#Preview {
    MonthYearPickerView(
        selectedDate: .constant(Date()),
        isPresented: .constant(true)
    )
    .preferredColorScheme(.dark)
}
