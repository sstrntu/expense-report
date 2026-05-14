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

## Pre-database scope

The app is currently a SwiftUI prototype backed by `Mock/MockData.swift`.

Before wiring a database or API, use the repo-level docs to finish the product and data contract:

- `docs/v1-pre-db-scope.md` — v1 feature scope, expense workflows, project policy rules, AI receipt scanning, and multi-workspace behavior.
- `docs/database-integration-contract.md` — backend-facing entities, statuses, repository boundaries, and security rules.
- `docs/pre-db-implementation-checklist.md` — implementation checklist for preparing the app before persistence.

The confirmed v1 scope includes both pre-approval and reimbursement claims, manager and finance reimbursement paths, project-controlled permissions/budgets/policies/member access, AI receipt scanning, and multi-workspace support.

## Supabase and OpenAI keys

Use Supabase public config in the iOS app and keep OpenAI server-side:

- iOS app: `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY`
- Supabase Edge Functions: `OPENAI_API_KEY`

The app reads public Supabase values through `Theme/AppEnvironment.swift`.
The OpenAI receipt scan scaffold lives at `../supabase/functions/scan-receipt/index.ts`.

See `../docs/supabase-openai-setup.md` for the exact setup flow.
