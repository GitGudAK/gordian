// Decision follow-up loop ("close the loop"): a local notification N days after a
// verdict asks whether the user acted on their decision, answerable from the
// notification itself. No backend, no push service — everything on-device.

import Foundation
import UserNotifications
import SwiftData

@MainActor
final class FollowUpManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = FollowUpManager()

    static let categoryID = "GORDIAN_FOLLOW_UP"
    static let actedActionID = "ACTED_YES"
    static let notYetActionID = "ACTED_NO"
    private static let enabledKey = "follow_ups_enabled"

    private var container: ModelContainer?

    var followUpsEnabled: Bool {
        get { UserDefaults.standard.object(forKey: Self.enabledKey) as? Bool ?? true }
        set {
            UserDefaults.standard.set(newValue, forKey: Self.enabledKey)
            if !newValue { cancelAllFollowUps() }
        }
    }

    /// Call once at app start, before any notification can be delivered.
    func configure(container: ModelContainer) {
        self.container = container
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        let acted = UNNotificationAction(identifier: Self.actedActionID, title: "I acted on it")
        let notYet = UNNotificationAction(identifier: Self.notYetActionID, title: "Not yet")
        let category = UNNotificationCategory(
            identifier: Self.categoryID,
            actions: [acted, notYet],
            intentIdentifiers: []
        )
        center.setNotificationCategories([category])
    }

    /// Permission is requested here — at the moment of first value, not at launch.
    func scheduleFollowUp(decision: String, followUpID: String) {
        guard followUpsEnabled, !decision.isEmpty else { return }
        Task {
            let center = UNUserNotificationCenter.current()
            let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
            guard granted else { return }

            let content = UNMutableNotificationContent()
            content.title = "Close the loop"
            content.body = "You decided: \(decision) Did you act on it?"
            content.sound = .default
            content.categoryIdentifier = Self.categoryID
            content.userInfo = ["followUpID": followUpID]

            var interval: TimeInterval = 3 * 24 * 3600
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-fastFollowUp") { interval = 10 }
            #endif

            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
            try? await center.add(UNNotificationRequest(identifier: followUpID, content: content, trigger: trigger))
        }
    }

    func cancelFollowUp(id: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
    }

    func cancelAllFollowUps() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    // MARK: - UNUserNotificationCenterDelegate

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let id = response.notification.request.content.userInfo["followUpID"] as? String
        let action = response.actionIdentifier
        await MainActor.run {
            guard let id, let container = self.container else { return }
            let status: String
            switch action {
            case Self.actedActionID: status = "acted"
            case Self.notYetActionID: status = "not_acted"
            default: return // plain tap opens the app; no state change
            }
            let context = container.mainContext
            let descriptor = FetchDescriptor<DecisionLog>(predicate: #Predicate { $0.followUpID == id })
            if let log = try? context.fetch(descriptor).first {
                log.actedOn = status
                try? context.save()
            }
        }
    }
}
