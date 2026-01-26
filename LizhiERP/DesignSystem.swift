import SwiftUI

// MARK: - Colors
extension Color {
    static let lizhiOrange = LinearGradient(
        colors: [Color.orange, Color.red.opacity(0.8)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let lizhiGold = LinearGradient(
        colors: [Color.yellow, Color.orange],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let fireGreen = LinearGradient(
        colors: [Color(hex: "00C853"), Color(hex: "69F0AE")], // Emerald/Mint
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // Helper for Hex
    init(hex: String) {
        let scanner = Scanner(string: hex)
        _ = scanner.scanString("#")
        
        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)
        
        let r = Double((rgb >> 16) & 0xFF) / 255.0
        let g = Double((rgb >> 8) & 0xFF) / 255.0
        let b = Double(rgb & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Modifiers
struct GlassCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: .white.opacity(0.1), radius: 10, x: 0, y: 5)
            .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

extension View {
    func glassCard() -> some View {
        self.modifier(GlassCardModifier())
    }
    
    func liquidBackground() -> some View {
        self.background(
            Color(uiColor: .systemBackground) // Solid, adaptive background (White in Light, Black in Dark)
                .ignoresSafeArea()
        )
    }
}

// MARK: - Haptics
enum HapticFeedbackStyle {
    case hustle   // Sharp, crisp (Success)
    case freedom  // Long, heavy (Anchor)
    case glassTap // Subtle
}

func triggerHaptic(_ style: HapticFeedbackStyle) {
    let generator = UIImpactFeedbackGenerator(style: .medium) // Default base
    switch style {
    case .hustle:
        let rigid = UIImpactFeedbackGenerator(style: .rigid)
        rigid.prepare()
        rigid.impactOccurred()
    case .freedom:
        let heavy = UIImpactFeedbackGenerator(style: .heavy)
        heavy.prepare()
        heavy.impactOccurred()
    case .glassTap:
        let light = UIImpactFeedbackGenerator(style: .light)
        light.prepare()
        light.impactOccurred()
    }
}

// MARK: - Reusable UI Components
struct PageHeader<CenterContent: View, RightContent: View>: View {
    let title: String
    let leftAction: (() -> Void)?
    var centerContent: () -> CenterContent
    var rightContent: () -> RightContent
    
    init(
        title: String,
        leftAction: (() -> Void)? = nil,
        @ViewBuilder centerContent: @escaping () -> CenterContent = { EmptyView() },
        @ViewBuilder rightContent: @escaping () -> RightContent = { EmptyView() }
    ) {
        self.title = title
        self.leftAction = leftAction
        self.centerContent = centerContent
        self.rightContent = rightContent
    }
    
    var body: some View {
        HStack {
            // Left: Back Button or Title
            if let action = leftAction {
                Button(action: action) {
                    Image(systemName: "arrow.left")
                        .font(.title3) // Standardized size
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Color(white: 0.15)) // Unify gray
                        .clipShape(Circle())
                }
            }
            
            // Center: Title or Custom View (e.g. Month Picker)
            // If custom view is EmptyView, show Title here?
            // Actually, typical pattern:
            // Left = Back, Center = Title/Control, Right = Actions
            
            Spacer()
            
            if CenterContent.self != EmptyView.self {
                centerContent()
            } else {
                Text(title)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
            }
            
            Spacer()
            
            // Right: Actions
            rightContent()
                .frame(minWidth: 44, alignment: .trailing) // Balance the left side
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 12)
        .background(Color.black) // Ensure background matches
    }
}

// Helpers for unified button styles
extension View {
    func standardButtonStyle() -> some View {
        self
            .font(.body)
            .foregroundStyle(.white)
            .padding(10)
            .background(Color(white: 0.15))
            .clipShape(Circle())
    }
}
