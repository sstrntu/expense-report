# Turfmapp Expense Report — iOS (SwiftUI)

Requires **Xcode 26** and **iOS 26 Simulator** for true liquid glass (`.glassEffect()`).

---

## Getting into Xcode — two paths

### Path A: XcodeGen (recommended, one command)

1. Install XcodeGen once:
   ```
   brew install xcodegen
   ```
2. In this `ios/` folder, run:
   ```
   xcodegen generate
   ```
3. Open `TurfmappExpenseReport.xcodeproj`, select an iOS 26 simulator, press **⌘R**.

### Path B: Manual drag-in (no extra tools)

1. Open Xcode 26 → **File > New > Project**
2. Choose **iOS > App**, name it `TurfmappExpenseReport`, interface **SwiftUI**, language **Swift**
3. Delete the default `ContentView.swift`
4. Drag the entire `TurfmappExpenseReport/` folder from Finder into the project navigator  
   (check **"Copy items if needed"** and **"Create groups"**)
5. Select an iOS 26 simulator → **⌘R**

---

## Project structure

```
ios/
├── project.yml                         ← XcodeGen config
└── TurfmappExpenseReport/
    ├── TurfmappExpenseReportApp.swift   ← @main entry
    ├── Info.plist
    ├── Assets.xcassets/
    ├── Theme/
    │   ├── Tokens.swift                ← Color + spacing constants
    │   └── AppTheme.swift              ← AppState, AppRole, background helper
    ├── Models/
    │   └── Models.swift                ← Expense, Project, Company, Member
    ├── Mock/
    │   └── MockData.swift              ← All sample data
    ├── Components/
    │   ├── GlassCard.swift             ← .glassEffect() wrapper
    │   ├── StatusPill.swift
    │   ├── Avatar.swift
    │   └── Charts.swift                ← Sparkline, Donut, Bars
    ├── Screens/
    │   ├── HomeView.swift
    │   ├── DashboardView.swift
    │   ├── ActivityView.swift
    │   ├── SubmitView.swift
    │   ├── DetailView.swift
    │   ├── ManagerOverviewView.swift
    │   ├── ReviewView.swift
    │   ├── ProfileView.swift
    │   ├── ManageProjectsView.swift
    │   └── PermissionsView.swift
    └── Shell/
        ├── RootShell.swift             ← App shell, nav stack, debug menu
        └── BottomTabBar.swift          ← Liquid glass tab bar
```

---

## Features

| Feature | Status |
|---------|--------|
| Liquid glass tab bar (`.glassEffect(.regular.interactive())`) | ✅ |
| Light/dark mode (system-driven) | ✅ |
| Employee / Manager role toggle (shake → debug menu) | ✅ |
| Workspace switcher (4 companies) | ✅ |
| Home — hero balance, sparkline, AI insight, recent activity | ✅ |
| Dashboard — donut chart, bar chart, KPI grid, top merchants | ✅ |
| Submit — camera scan flow + AI extraction animation | ✅ |
| Activity — grouped expense list with filters | ✅ |
| Expense detail — approve / reject (manager) | ✅ |
| Manager overview — approval queue, project budgets | ✅ |
| Review — approval queue list | ✅ |
| Manage projects — list + create form | ✅ |
| Permissions — role picker, approval policy toggles | ✅ |
| Profile — account settings, workspace admin links | ✅ |

---

## Wiring to a real API (later)

All data currently lives in `Mock/MockData.swift`.  
When ready, replace with:
- A `@MainActor class ExpenseService: ObservableObject` that fetches from your API
- Inject it via `.environmentObject(ExpenseService())` in `TurfmappExpenseReportApp`
- Views already use `MockData.*` in isolated spots — easy to swap call-by-call
