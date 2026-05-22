import UIKit
import UserNotifications

extension Notification.Name {
    static let deviceTokenReceived   = Notification.Name("com.turfmapp.deviceTokenReceived")
    static let pushNotificationOpened = Notification.Name("com.turfmapp.pushNotificationOpened")
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, @unchecked Sendable {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        requestPushPermission()
        // Cold-start: app was killed, user tapped a push — handle immediately
        if let payload = launchOptions?[.remoteNotification] as? [String: Any] {
            handlePayload(payload)
        }
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        NotificationCenter.default.post(name: .deviceTokenReceived, object: nil, userInfo: ["token": token])
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        // Silently ignored — Simulator always fails; device users only lose push, not core features.
    }

    // Show banner + sound when notification arrives while app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    // User tapped a notification from the lock screen / notification center
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        handlePayload(response.notification.request.content.userInfo as? [String: Any] ?? [:])
        completionHandler()
    }

    private func requestPushPermission() {
        Task {
            let granted = (try? await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])) ?? false
            if granted {
                await MainActor.run { UIApplication.shared.registerForRemoteNotifications() }
            }
        }
    }

    private func handlePayload(_ payload: [String: Any]) {
        // APNs custom payload: { "expense_id": "<uuid>" }
        guard let expenseId = payload["expense_id"] as? String ?? payload["expenseId"] as? String,
              !expenseId.isEmpty else { return }
        NotificationCenter.default.post(
            name: .pushNotificationOpened,
            object: nil,
            userInfo: ["expenseId": expenseId]
        )
    }
}
