import UIKit
import UserNotifications

extension Notification.Name {
    static let deviceTokenReceived   = Notification.Name("com.turfmapp.deviceTokenReceived")
    static let pushNotificationOpened = Notification.Name("com.turfmapp.pushNotificationOpened")
    /// Posted from Profile → Replay app tour to trigger the FeatureTour overlay.
    /// RootShell listens on this notification and flips `showTour = true`.
    static let replayFeatureTour     = Notification.Name("com.turfmapp.replayFeatureTour")
}

@MainActor
final class AppDelegate: NSObject, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        requestPushPermission()
        if let payload = launchOptions?[.remoteNotification] as? [String: Any] {
            handlePayload(payload)
        }
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        // Persist so bootstrap can register it even if the token arrives before appShell renders.
        UserDefaults.standard.set(token, forKey: "apns.device.token")
        NotificationCenter.default.post(name: .deviceTokenReceived, object: nil, userInfo: ["token": token])
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {}

    private func requestPushPermission() {
        Task {
            let granted = (try? await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])) ?? false
            if granted {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }

    fileprivate func handlePayload(_ payload: [String: Any]) {
        guard let expenseId = payload["expense_id"] as? String ?? payload["expenseId"] as? String,
              !expenseId.isEmpty else { return }
        NotificationCenter.default.post(
            name: .pushNotificationOpened,
            object: nil,
            userInfo: ["expenseId": expenseId]
        )
    }
}

// @preconcurrency suppresses the Swift 6 crossing warning — UNUserNotificationCenterDelegate
// is not @MainActor-annotated in the SDK, but its callbacks always arrive on the main thread.
extension AppDelegate: @preconcurrency UNUserNotificationCenterDelegate {

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        handlePayload(response.notification.request.content.userInfo as? [String: Any] ?? [:])
        completionHandler()
    }
}
