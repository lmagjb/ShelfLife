import Foundation

// MARK: - History
/// A record of what happened to an item after it left the list:
/// used in time, wasted (deleted after it expired) or returned.
/// Saved in Firestore at users/{userID}/history/{itemID}, so Insights
/// can show money saved and wasted over time.

enum HistoryOutcome: String, Codable {
    case used = "Used"
    case wasted = "Wasted"
    case returned = "Returned"
}

struct HistoryEntry: Identifiable, Codable {
    /// Same id as the item it came from, so Undo can remove it again.
    var id: String
    var name: String
    var emoji: String
    var category: ItemCategory
    var amount: Double?
    var outcome: HistoryOutcome
    var date: Date

    init(item: PantryItem, outcome: HistoryOutcome) {
        self.id = item.id
        self.name = item.name
        self.emoji = item.emoji
        self.category = item.category
        self.amount = item.amount
        self.outcome = outcome
        self.date = Date()
    }
}

/// One bar group in the monthly chart.
struct MonthSummary: Identifiable {
    let id: Date          // first day of the month
    var label: String     // "Nov"
    var used: Double
    var wasted: Double
}
