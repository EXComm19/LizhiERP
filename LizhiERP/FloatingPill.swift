import SwiftUI

enum Tab: String, CaseIterable {
    case cockpit = "Cockpit"
    case ledger = "Ledger"
    case pulse = "Pulse"
    case vault = "Vault"
    case lens = "Lens"
    
    var icon: String {
        switch self {
        case .cockpit: return "house"
        case .ledger: return "list.bullet"
        case .pulse: return "bolt"
        case .vault: return "building.columns"
        case .lens: return "camera"
        }
    }
}

struct FloatingPill: View {
    @Binding var selectedTab: Tab
    var onActionTap: () -> Void
    
    @Namespace private var animation
    
    var body: some View {
        HStack(spacing: 0) {
            // The Pill
            HStack(spacing: 0) {
                ForEach(Tab.allCases, id: \.self) { tab in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedTab = tab
                        }
                        triggerHaptic(.glassTap)
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 22, weight: .semibold))
                                .symbolVariant(selectedTab == tab ? .fill : .none)
                            
                            if selectedTab == tab {
                                Circle()
                                    .fill(Color.primary) // Adaptive Dot
                                    .frame(width: 4, height: 4)
                                    .matchedGeometryEffect(id: "TabDot", in: animation)
                            } else {
                                Circle().fill(.clear).frame(width: 4, height: 4)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .foregroundStyle(selectedTab == tab ? Color.primary : Color.secondary)
                    }
                }
            }
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
            
            Spacer()
                .frame(width: 16)
            
            // The Action Button (Floating Right)
            Button(action: {
                triggerHaptic(.hustle)
                onActionTap()
            }) {
                Image(systemName: "plus")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(Color.lizhiOrange)
                    .clipShape(Circle())
                    .shadow(color: .orange.opacity(0.4), radius: 8, x: 0, y: 4)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 8)
    }
}
