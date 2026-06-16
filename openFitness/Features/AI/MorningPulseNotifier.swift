import Foundation
import UIKit
import UserNotifications

/// Delivers the AI daily pulse as a local notification once per morning.
///
/// There is no scheduled trigger: iOS wakes the app via the existing BGAppRefresh
/// task and HealthKit background deliveries, and the first wake inside the morning
/// window generates the pulse and posts it immediately. If no background wake
/// happens (iOS discretion), the user simply sees the pulse in-app instead.
@MainActor
enum MorningPulseNotifier {
    private static let deliveredDayKey = "ai.morningPulse.deliveredDay"
    private static let notificationId = "ai.morningPulse"

    /// Morning window during which a background wake produces the notification.
    private static let deliveryHours = 7..<12

    /// Asks for notification permission once, and only on devices where the
    /// feature can actually run. Safe to call on every launch.
    static func requestPermissionIfNeeded() async {
        guard AIInsightEngine.isAvailable else { return }
        let center = UNUserNotificationCenter.current()
        guard await center.notificationSettings().authorizationStatus == .notDetermined else { return }
        _ = try? await center.requestAuthorization(options: [.alert, .sound])
    }

    /// Called from background wakes after `loadMetricsFromLocalStore()` has run
    /// on `hkManager`. Generates and posts the pulse if it is due.
    static func deliverIfDue(using hkManager: HealthKitManager) async {
        guard AIInsightEngine.isAvailable else { return }

        // In the foreground the dashboard bubble shows the same content
        guard UIApplication.shared.applicationState != .active else { return }

        let hour = Calendar.current.component(.hour, from: Date())
        guard deliveryHours.contains(hour) else { return }

        let today = AIToolFormat.makeDayFormatter().string(from: Date())
        guard UserDefaults.standard.string(forKey: deliveredDayKey) != today else { return }

        let settings = await UNUserNotificationCenter.current().notificationSettings()
        guard settings.authorizationStatus == .authorized else { return }

        // Don't write a pulse from an empty snapshot (store not yet populated)
        guard hkManager.todayRecovery > 0 || hkManager.todaySteps > 0 || hkManager.todayStrain > 0 else { return }

        guard let pulse = try? await AIInsightEngine.shared.dailyPulse(using: hkManager) else { return }

        let content = UNMutableNotificationContent()
        content.title = pulse.headline
        content.body = pulse.message
        content.sound = .default

        let request = UNNotificationRequest(identifier: notificationId, content: content, trigger: nil)
        do {
            try await UNUserNotificationCenter.current().add(request)
            markSeenToday()
        } catch {
            // Leave deliveredDay unset so a later wake can retry
        }
    }

    /// The dashboard calls this when the pulse bubble is shown, so a later
    /// background wake doesn't notify about content the user has already seen.
    static func markSeenToday() {
        let today = AIToolFormat.makeDayFormatter().string(from: Date())
        UserDefaults.standard.set(today, forKey: deliveredDayKey)
    }
}
