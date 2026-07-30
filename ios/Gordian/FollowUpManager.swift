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
    private static let dailyKnotKey = "daily_knot_enabled"
    private static let weeklyRecapKey = "weekly_recap_enabled"
    private static let dailyKnotIDPrefix = "DAILY_KNOT_"
    private static let weeklyRecapID = "WEEKLY_RECAP"

    private var container: ModelContainer?

    var followUpsEnabled: Bool {
        get { UserDefaults.standard.object(forKey: Self.enabledKey) as? Bool ?? true }
        set {
            UserDefaults.standard.set(newValue, forKey: Self.enabledKey)
            if !newValue { cancelAllFollowUps() }
        }
    }

    // Daily Knot is opt-in — a daily notification must be chosen, never imposed
    var dailyKnotEnabled: Bool {
        get { UserDefaults.standard.object(forKey: Self.dailyKnotKey) as? Bool ?? false }
        set {
            UserDefaults.standard.set(newValue, forKey: Self.dailyKnotKey)
            if newValue {
                Task { await self.requestAuthAndRefresh() }
            } else {
                cancelDailyKnots()
            }
        }
    }

    var weeklyRecapEnabled: Bool {
        get { UserDefaults.standard.object(forKey: Self.weeklyRecapKey) as? Bool ?? true }
        set {
            UserDefaults.standard.set(newValue, forKey: Self.weeklyRecapKey)
            if newValue {
                Task { await self.requestAuthAndRefresh() }
            } else {
                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [Self.weeklyRecapID])
            }
        }
    }

    static let dailyKnotQuestions = [
        "What did you avoid deciding today?",
        "What would you do if you couldn't fail?",
        "What decision have you been rationalizing instead of making?",
        "Which open loop drains you most right now?",
        "What would your 80-year-old self tell you to do today?",
        "What are you pretending not to know?",
        "If today repeated for a year, would that be fine?",
        "What's the smallest step you're avoiding?",
        "Whose approval are you waiting for — and why?",
        "What deadline would force your hand, helpfully?",
        "What choice keeps returning to your mind at night?",
        "What would you drop if no one would notice?",
        "Comfort or growth — which did you pick today?",
        "What is fear currently costing you?",
        "What decision would future-you thank you for?",
        "Which yes should have been a no this week?",
        "What are you overthinking right now?",
        "If you had to decide in 60 seconds, what would it be?",
        "What's one thing you know but keep ignoring?",
        "Where are you seeking consensus to avoid owning a choice?",
        "What knot have you been carrying all week?"
    ]

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

    /// A single digest identifier: there is never more than ONE pending
    /// follow-up notification. Heavy use used to schedule one per verdict, and
    /// they all landed together days later as a pile.
    private static let digestID = "GORDIAN_FOLLOW_UP_DIGEST"

    /// Permission is requested here — at the moment of first value, not at launch.
    /// Every completed verdict replaces the pending digest: one decision gets
    /// the personal ask (with action buttons); several get one summary.
    func scheduleFollowUp(decision: String, followUpID: String) {
        guard followUpsEnabled, !decision.isEmpty else { return }
        #if DEBUG
        // Screenshot tooling: never surface the permission dialog
        if ProcessInfo.processInfo.arguments.contains("-noNotifPrompt") { return }
        #endif
        Task {
            let center = UNUserNotificationCenter.current()
            let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
            guard granted else { return }
            await rebuildDigest(latestDecision: decision, latestFollowUpID: followUpID)
        }
    }

    /// Recomputes the one pending follow-up from the store. Called after a
    /// verdict (with the fresh decision) and after a log deletion (without).
    private func rebuildDigest(latestDecision: String? = nil, latestFollowUpID: String? = nil) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.digestID])

        let pendingCount = pendingFollowUpCount()
        guard pendingCount > 0 else { return }

        let content = UNMutableNotificationContent()
        content.sound = .default
        if pendingCount == 1, let decision = latestDecision, let id = latestFollowUpID {
            // One open loop: the personal ask, answerable from the notification
            content.title = "Close the loop"
            content.body = "You decided: \(decision) Did you act on it?"
            content.categoryIdentifier = Self.categoryID
            content.userInfo = ["followUpID": id]
        } else {
            // Several open loops: one summary; tapping opens the app, and
            // Logs handles the per-decision answers
            content.title = "Close the loops"
            content.body = "You untied \(pendingCount) knots recently. Did you act on them?"
        }

        var interval: TimeInterval = 3 * 24 * 3600
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-fastFollowUp") { interval = 10 }
        #endif
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        try? await center.add(UNNotificationRequest(identifier: Self.digestID, content: content, trigger: trigger))
    }

    /// Logs whose follow-up question is still unanswered.
    private func pendingFollowUpCount() -> Int {
        guard let container else { return 0 }
        let descriptor = FetchDescriptor<DecisionLog>(predicate: #Predicate { $0.actedOn == "pending" })
        return (try? container.mainContext.fetchCount(descriptor)) ?? 0
    }

    func cancelFollowUp(id: String) {
        // Legacy per-verdict requests used the followUpID as identifier;
        // remove those too so upgrades from old builds don't leave strays
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
        Task { await rebuildDigest() }
    }

    func cancelAllFollowUps() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    private func cancelDailyKnots() {
        let ids = (0...14).map { "\(Self.dailyKnotIDPrefix)\($0)" }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }

    private func requestAuthAndRefresh() async {
        let center = UNUserNotificationCenter.current()
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
        refreshScheduledContent()
    }

    /// Re-plans Daily Knot and Weekly Recap. Call on app foreground — content is
    /// recomputed each time so recap numbers stay fresh. Only schedules when the
    /// user has already granted notification permission.
    func refreshScheduledContent() {
        Task {
            let center = UNUserNotificationCenter.current()
            let settings = await center.notificationSettings()
            guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }
            let calendar = Calendar.current

            #if DEBUG
            // -fastDailyKnot: fire a Daily Knot in 6s and a Weekly Recap in 14s so the
            // experience can be seen without waiting for 9:00 or Sunday
            if ProcessInfo.processInfo.arguments.contains("-fastDailyKnot") {
                let knot = UNMutableNotificationContent()
                knot.title = "The Daily Knot"
                knot.body = Self.dailyKnotQuestions[(calendar.ordinality(of: .day, in: .year, for: Date()) ?? 0) % Self.dailyKnotQuestions.count]
                knot.sound = .default
                try? await center.add(UNNotificationRequest(
                    identifier: "\(Self.dailyKnotIDPrefix)DEMO",
                    content: knot,
                    trigger: UNTimeIntervalNotificationTrigger(timeInterval: 6, repeats: false)
                ))
                let recap = UNMutableNotificationContent()
                recap.title = "Your week in decisions"
                recap.body = weeklyRecapBody() ?? "This week: 2 knots untied, 1 acted on."
                recap.sound = .default
                try? await center.add(UNNotificationRequest(
                    identifier: "\(Self.weeklyRecapID)_DEMO",
                    content: recap,
                    trigger: UNTimeIntervalNotificationTrigger(timeInterval: 14, repeats: false)
                ))
            }
            #endif

            // Daily Knot: next 7 mornings at 9:00, a different question each day
            if dailyKnotEnabled {
                cancelDailyKnots()
                let dayOfYear = calendar.ordinality(of: .day, in: .year, for: Date()) ?? 0
                for offset in 0..<7 {
                    guard let day = calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: Date())) else { continue }
                    var components = calendar.dateComponents([.year, .month, .day], from: day)
                    components.hour = 9
                    guard let fireDate = calendar.date(from: components), fireDate > Date() else { continue }
                    let content = UNMutableNotificationContent()
                    content.title = "The Daily Knot"
                    content.body = Self.dailyKnotQuestions[(dayOfYear + offset) % Self.dailyKnotQuestions.count]
                    content.sound = .default
                    try? await center.add(UNNotificationRequest(
                        identifier: "\(Self.dailyKnotIDPrefix)\(offset)",
                        content: content,
                        trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                    ))
                }
            }

            // Weekly Recap: next Sunday 18:00 — only when this week actually had sessions
            center.removePendingNotificationRequests(withIdentifiers: [Self.weeklyRecapID])
            if weeklyRecapEnabled, let body = weeklyRecapBody() {
                let content = UNMutableNotificationContent()
                content.title = "Your week in decisions"
                content.body = body
                content.sound = .default
                var components = DateComponents()
                components.weekday = 1
                components.hour = 18
                try? await center.add(UNNotificationRequest(
                    identifier: Self.weeklyRecapID,
                    content: content,
                    trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                ))
            }
        }
    }

    /// nil when the week has no sessions — no sessions, no notification (never nag)
    private func weeklyRecapBody() -> String? {
        guard let container else { return nil }
        let calendar = Calendar.current
        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: Date())?.start else { return nil }
        let descriptor = FetchDescriptor<DecisionLog>(predicate: #Predicate { $0.timestamp >= weekStart })
        guard let logs = try? container.mainContext.fetch(descriptor), !logs.isEmpty else { return nil }
        let acted = logs.filter { $0.actedOn == "acted" }.count
        let knots = logs.count
        var body = "This week: \(knots) knot\(knots == 1 ? "" : "s") untied"
        body += acted > 0 ? ", \(acted) acted on." : "."
        return body
    }

    // MARK: - UNUserNotificationCenterDelegate
    //
    // Completion-handler variants, completed on the main queue. The async
    // variants resume on a background executor, and UIKit's bridged completion
    // then runs its snapshot/state-restoration work off-main — an
    // NSInternalInconsistencyException ("Call must be made on main thread")
    // that only fires on notification cold launches.

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        DispatchQueue.main.async {
            completionHandler([.banner, .sound])
        }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let id = response.notification.request.content.userInfo["followUpID"] as? String
        let action = response.actionIdentifier
        DispatchQueue.main.async {
            MainActor.assumeIsolated {
                defer { completionHandler() }
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
}
