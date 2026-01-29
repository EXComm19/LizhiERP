import SwiftUI
import SwiftData

struct RootView: View {
    @State private var selectedTab: Tab = .cockpit
    
    // Sheet States
    @State private var showTransactionEditor: Bool = false
    @State private var showAssetEditor: Bool = false
    @State private var showPhysicalAssetEditor: Bool = false
    @State private var showSubscriptionEditor: Bool = false
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Background
            Color.lizhiBackground.ignoresSafeArea()
            
            // Screen Content
            Group {
                switch selectedTab {
                case .cockpit:
                    CockpitView()
                case .ledger:
                    LedgerView()
                case .pulse:
                    PulseManagerView()
                case .vault:
                    VaultView()
                case .lens:
                    LensView() // Needs refactor to be the Asset Manager Page
                }
            }
            .transition(.opacity.animation(.easeInOut))
            
            // Floating Navigation
            FloatingPill(selectedTab: $selectedTab, onActionTap: handleFabTap)
        }
        .sheet(isPresented: $showTransactionEditor) {
            ManualTransactionView(isPresented: $showTransactionEditor)
        }
        .sheet(isPresented: $showAssetEditor) {
            VaultAssetEditor(isPresented: $showAssetEditor)
        }
        .sheet(isPresented: $showPhysicalAssetEditor) {
            PhysicalAssetEditor(isPresented: $showPhysicalAssetEditor)
        }
        .sheet(isPresented: $showSubscriptionEditor) {
            SubscriptionEditorView(isPresented: $showSubscriptionEditor)
        }
    }
    
    func handleFabTap() {
        switch selectedTab {
        case .cockpit, .ledger:
            showTransactionEditor = true
        case .pulse:
            showSubscriptionEditor = true 
        case .vault:
            // "Add button prompts to add a fund"
            showAssetEditor = true
        case .lens:
            // "Add button prompts to add an object"
            showPhysicalAssetEditor = true
        }
    }
}

