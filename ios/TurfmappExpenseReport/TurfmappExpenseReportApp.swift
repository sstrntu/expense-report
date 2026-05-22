import SwiftUI

@main
struct TurfmappExpenseReportApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            RootShell()
        }
    }
}
