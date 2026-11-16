import Foundation
import UserNotifications

// MARK: - Reminder settings
/// Saved on the phone with UserDefaults. The Settings screen edits the
/// same keys through @AppStorage, so both always agree.
enum ReminderSettings {
    static let enabledKey    = "remindersEnabled"
    static let minutesKey    = "reminderMinutes"     // minutes after midnight
    static let daysBeforeKey = "reminderDaysBefore"

    static let defaultMinutes = 21 * 60              // 9:00 PM
    static let defaultDaysBefore = 1

    static var enabled: Bool {
        UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true
    }
    static var minutes: Int {
        UserDefaults.standard.object(forKey: minutesKey) as? Int ?? defaultMinutes
    }
    static var daysBefore: Int {
        UserDefaults.standard.object(forKey: daysBeforeKey) as? Int ?? defaultDaysBefore
    }
}

// MARK: - Notification buttons
/// A button tapped on a reminder, waiting for the item to load.
struct NotificationAction {
    enum Kind { case markUsed, extend3 }
    let itemID: String
    let kind: Kind
}

// MARK: - Reminder manager
/// Schedules real iPhone notifications before items expire.
/// These are local notifications: the phone fires them itself at the set
/// time, even when the app is closed. No server is involved.
final class ReminderManager {
    static let shared = ReminderManager()
    private let center = UNUserNotificationCenter.current()

    /// iOS keeps at most 64 pending notifications per app.
    private let maxPending = 60

    /// Reminder button taps that the store hasn't applied yet.
    var pendingActions: [NotificationAction] = []

    static let foodCategory = "FOOD_DEADLINE"
    static let markUsedAction = "MARK_USED"
    static let extendAction = "EXTEND_3"

    private init() {}

    /// Adds "Mark used" and "+3 days" buttons to food reminders.
    /// Both open the app, so the change is saved while it's running.
    func registerActions() {
        let markUsed = UNNotificationAction(identifier: Self.markUsedAction,
                                            title: "Mark used", options: [.foreground])
        let extend = UNNotificationAction(identifier: Self.extendAction,
                                          title: "+3 days", options: [.foreground])
        let food = UNNotificationCategory(identifier: Self.foodCategory,
                                          actions: [markUsed, extend],
                                          intentIdentifiers: [], options: [])
        center.setNotificationCategories([food])
    }

    /// Called by the app delegate when a reminder button is tapped.
    func handle(actionIdentifier: String, userInfo: [AnyHashable: Any]) {
        guard let itemID = userInfo["itemID"] as? String else { return }
        switch actionIdentifier {
        case Self.markUsedAction: pendingActions.append(NotificationAction(itemID: itemID, kind: .markUsed))
        case Self.extendAction:   pendingActions.append(NotificationAction(itemID: itemID, kind: .extend3))
        default: break
        }
    }

    /// The app icon badge: items due today or overdue.
    func updateBadge(_ count: Int) {
        center.setBadgeCount(count) { error in
            if let error { print("Could not set badge:", error.localizedDescription) }
        }
    }

    /// Shows the iOS "Allow notifications?" prompt the first time.
    func requestPermission() {
        center.requestAuthorization(options: [.alert, .sound, .badge]) { _, error in
            if let error { print("Notification permission error:", error.localizedDescription) }
        }
    }

    /// Whether the user allowed notifications in iOS Settings.
    func checkPermission(_ completion: @escaping (Bool) -> Void) {
        center.getNotificationSettings { settings in
            let allowed = settings.authorizationStatus == .authorized
                || settings.authorizationStatus == .provisional
            DispatchQueue.main.async { completion(allowed) }
        }
    }

    func removeAll() {
        center.removeAllPendingNotificationRequests()
        pendingActions = []
        updateBadge(0)
    }

    /// Clears every pending reminder and builds a fresh set from `items`.
    /// Called whenever the item list changes, so adding, editing,
    /// extending, deleting and undoing all stay in sync on their own.
    func reschedule(for items: [PantryItem]) {
        center.removeAllPendingNotificationRequests()
        updateBadge(items.filter { $0.activeDaysLeft <= 0 }.count)
        guard ReminderSettings.enabled else { return }

        var planned: [(date: Date, request: UNNotificationRequest)] = []

        for item in items where item.notify {
            if let reminder = makeReminder(for: item, deadline: item.expiryDate, isWarranty: false) {
                planned.append(reminder)
            }
            if item.type == .purchase, let warranty = item.warrantyDate,
               let reminder = makeReminder(for: item, deadline: warranty, isWarranty: true) {
                planned.append(reminder)
            }
        }

        // Keep the soonest ones if there are more than iOS allows.
        for reminder in planned.sorted(by: { $0.date < $1.date }).prefix(maxPending) {
            // When it fires, the badge counts everything due by that day.
            let content = (reminder.request.content.mutableCopy() as? UNMutableNotificationContent)
                ?? UNMutableNotificationContent()
            let fireDay = Calendar.current.startOfDay(for: reminder.date)
            let dueBy = items.filter { item in
                let deadline = item.isUnderWarrantyOnly ? (item.warrantyDate ?? item.expiryDate) : item.expiryDate
                return Calendar.current.startOfDay(for: deadline) <= fireDay
            }.count
            content.badge = NSNumber(value: max(dueBy, 1))
            let request = UNNotificationRequest(identifier: reminder.request.identifier,
                                                content: content,
                                                trigger: reminder.request.trigger)
            center.add(request) { error in
                if let error { print("Could not schedule reminder:", error.localizedDescription) }
            }
        }
    }

    // MARK: Building one reminder

    private func makeReminder(for item: PantryItem, deadline: Date,
                              isWarranty: Bool) -> (date: Date, request: UNNotificationRequest)? {
        guard let timing = fireDate(for: deadline) else { return nil }
        let fireAt = timing.0
        let daysAhead = timing.1

        let content = UNMutableNotificationContent()
        content.title = "\(item.emoji) \(item.name)"
        content.body = message(for: item, daysAhead: daysAhead, isWarranty: isWarranty)
        content.sound = .default
        content.userInfo = ["itemID": item.id]
        if item.type == .food {
            content.categoryIdentifier = Self.foodCategory
        }

        let parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireAt)
        let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
        let id = "\(item.id)-\(isWarranty ? "warranty" : "deadline")"

        return (fireAt, UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    /// The chosen number of days before the deadline, at the chosen time.
    /// If that moment has already passed (an item added the day before it
    /// expires), it tries one day later, down to the deadline day itself.
    /// Also returns how many days ahead of the deadline it lands.
    private func fireDate(for deadline: Date) -> (Date, Int)? {
        let calendar = Calendar.current
        let deadlineDay = calendar.startOfDay(for: deadline)
        let minutes = ReminderSettings.minutes
        let daysBefore = max(ReminderSettings.daysBefore, 0)

        for ahead in stride(from: daysBefore, through: 0, by: -1) {
            guard let day = calendar.date(byAdding: .day, value: -ahead, to: deadlineDay),
                  let fire = calendar.date(byAdding: .minute, value: minutes, to: day)
            else { continue }
            if fire > Date() { return (fire, ahead) }
        }
        return nil
    }

    private func message(for item: PantryItem, daysAhead: Int, isWarranty: Bool) -> String {
        let when: String
        switch daysAhead {
        case 0:  when = "today"
        case 1:  when = "tomorrow"
        default: when = "in \(daysAhead) days"
        }

        if isWarranty {
            return "Warranty ends \(when). File any repair claim before then."
        }
        if item.isReturning {
            return "Drop it off \(when). The return window closes then."
        }
        if item.type == .purchase {
            return "Return window closes \(when). Start the return if you're not keeping it."
        }
        return "Expires \(when). Use it soon, or open ShelfLife for a rescue recipe."
    }
}
