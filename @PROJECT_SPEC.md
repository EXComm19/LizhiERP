# Project Name: Lizhi ERP (Life-Management OS)
# Context: Jan 2026
# Target OS: iOS 26 (Liquid Glass Design)

## 1. Project Manifesto
We are building a "Freedom OS" powered by cloud-native AI.
**Core Philosophy:**
1.  **The Lizhi Index (Hustle):** Measures Self-Sufficiency (Active Income / Spending).
2.  **The FIRE Projection (Freedom):** Measures Passive Income coverage.
3.  **The Oracle (Strategy):** We treat your financial history as a dataset for Gemini 3.0 to analyze, offering behavioral insights and complex future modeling (e.g., "Your 'Survival' spending is creeping up 3% faster than inflation").

## 2. Technical Stack (2026 Standard)
- **OS:** iOS 26.0+
- **Language:** Swift 7.0
- **AI Engine:** Gemini 3.0 Flash (via Google AI SDK)
    - *Role 1:* Multimodal Capture (Vision).
    - *Role 2:* Financial Analyst (Reasoning & Projection).
- **Data:** SwiftData (Schema v3)
- **UI:** SwiftUI 6 (Liquid Materials, Adaptive Layouts)

## 3. Data Architecture

### A. The Ledger
* **Transaction** (`@Model`, `Codable`):
    * `amount`: Decimal
    * `type`: Enum (Income, Expense)
    * `category`: Enum (Survival, Material, Experiential)
    * `source`: Enum (Job, SideProject, Investment, Gift)
    * `contextTags`: [String] (AI-generated tags like "Social", "Stress-Spending")

### B. The Vault (Assets)
* **AssetEntity** (`@Model`, `Codable`):
    * `ticker`: String
    * `holdings`: Decimal
    * `marketValue`: Decimal

## 4. Key Feature Implementation Plans

### Feature 1: The "Twin Gauge" Dashboard
**Goal:** Immediate status check.
* **Left (Lizhi):** "Hustle Meter" (Orange/Green liquid fill).
* **Right (FIRE):** "Freedom Meter" (Progress to 100% coverage).

### Feature 2: The "Oracle" (Cloud AI Analyst)
**Goal:** Complex forecasting and behavioral analysis.
* **Trigger:** Weekly "Strategy Review" or on-demand "Project my Future."
* **Payload:** Send last 12 months of JSON transaction data + Asset Portfolio to Gemini.
* **Prompt Strategy:**
    > "Analyze my spending velocity vs. investment growth. Project my FIRE date assuming my current 'Side Project' growth continues but my 'Experiential' spending aligns with holiday seasons. Flag any 'Lifestyle Creep' in the 'Survival' category."
* **Output:** A structured `FinancialForecast` object containing:
    * `estimatedFireDate`: Date
    * `lifestyleCreepIndex`: Double (0.0 - 1.0)
    * `actionableInsights`: [String] (e.g., "Switching your monthly coffee spend to IVV would accelerate FIRE by 14 days.")

### Feature 3: Visual Intelligence Entry
**Goal:** Frictionless capture.
* **Flow:** Snapshot -> Gemini Vision -> Structured JSON -> Auto-categorization (Survival vs. Experiential).

## 5. Coding Guidelines for AI
1.  **Codable Conformance:** Ensure all SwiftData models conform to `Codable` so they can be easily serialized into JSON for the Gemini API payload.
2.  **Latency Masking:** While Gemini analyzes the financial future (which might take 2-3 seconds), show a fluid, shimmering "Liquid Glass" animation in the UI.
3.  **Error Handling:** If the Cloud Analysis fails, fall back to a simple local linear projection.

## 6. System Connectivity & Logic (Strict Double-Entry)

### A. The "Unified Account" Model
* **Constraint:** All value containers (Banks, Wallets, Portfolios, Physical Inventory) must inherit from a base `Account` model.
* **Computed Balances:** `Account.balance` must be derived from the sum of associated `JournalEntry` records. Never hard-code a balance update.

### B. Transaction Flow Logic
* **Transfer Logic:** A transaction tagged as "Transfer" must have strict Source (`Credit`) and Destination (`Debit`) accounts.
* **Asset Purchase Logic:**
    * IF `Transaction.type` == `AssetPurchase` (e.g., Stock, Camera):
    * THEN:
        1.  Create `JournalEntry`: Credit `Bank Account`.
        2.  Create `JournalEntry`: Debit `Asset Account`.
        3.  Spawn `AssetLot` (for Stocks) or `PhysicalItem` (for Gear) linked to the Asset Account.

### C. Subscription Logic
* **Auto-Drafting:** The `SubscriptionService` must run a daily check.
* **Generation:** If `Date == BillingDate`, generate a `Transaction` with status `.pending`.
* **Reconciliation:** When a user inputs a real transaction (via AI/Manual) that matches a `.pending` subscription (fuzzy match on Amount + Payee), MERGE them and set status to `.cleared`.

### D. The "Lizhi" & FIRE Bridge
* **Data Source:**
    * **Lizhi Index** calculates primarily from `JournalEntry` records where `Account.type == .income` (Active) vs `.expense`.
    * **FIRE Projection** reads from `AssetLot.currentValue` (Passive Base) + `JournalEntry` (Spending History).
    * *Crucial:* Changes in the Asset Manager (e.g., Stock price goes up) do NOT affect the Lizhi Index (Active Income), but DO affect the FIRE Projection. Keep these logic streams separate.