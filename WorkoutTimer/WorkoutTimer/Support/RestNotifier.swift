import Foundation
import UserNotifications

/// Schedules a local notification for when the rest timer runs out,
/// so you get alerted even if the phone is locked or the app is in the background.
enum RestNotifier {
    private static let identifier = "rest-timer"

    static func requestAuthorization() {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    static func schedule(at date: Date, nextUp: String?) {
        cancel()
        let interval = date.timeIntervalSinceNow
        guard interval > 0.5 else { return }

        let content = UNMutableNotificationContent()
        content.title = "Rest over — time to lift! 💪"
        content.body = nextUp.map { "Next: \($0)" } ?? "Start your next set."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { _ in }
    }

    static func cancel() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        center.removeDeliveredNotifications(withIdentifiers: [identifier])
    }
}
