import SwiftUI
import Foundation
import FirebaseFirestore

// The palette and every glass component live in GlassKit.swift.

// MARK: - Money
/// Formats prices in the currency picked in Profile → Change currency.
/// Shows centavos only when there are some: ₱3,499 and ₱89.50.
enum Money {
    static let currencyKey = "currencyCode"
    static let defaultCode = "PHP"
    static let choices = ["PHP", "USD", "EUR", "GBP", "JPY", "SGD", "AUD", "CAD"]

    static var code: String {
        UserDefaults.standard.string(forKey: currencyKey) ?? defaultCode
    }

    static func format(_ amount: Double) -> String {
        let digits = amount == amount.rounded() ? 0 : 2
        return amount.formatted(.currency(code: code).precision(.fractionLength(digits)))
    }

    /// "₱", "$", "€"… for the price fields.
    static var symbol: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        return formatter.currencySymbol ?? code
    }
}

// MARK: - Enums

enum ItemCategory: String, Codable, CaseIterable, Identifiable {
    case dairy = "Dairy"
    case produce = "Produce"
    case meat = "Meat"
    case bakery = "Bakery"
    case pantry = "Pantry"
    case electronics = "Electronics"
    case home = "Home"
    case apparel = "Apparel"

    var id: Self { self }

    /// Food categories belong to pantry items; the rest to purchases.
    var isFood: Bool {
        switch self {
        case .dairy, .produce, .meat, .bakery, .pantry: return true
        case .electronics, .home, .apparel:             return false
        }
    }

    /// Emojis offered in the add form. The first one is the default.
    var emojiChoices: [String] {
        switch self {
        case .dairy:       return ["🥛", "🧀", "🧈", "🥚", "🍦", "🥣"]
        case .produce:     return ["🥬", "🍎", "🍌", "🥭", "🍅", "🥕", "🧅", "🥔"]
        case .meat:        return ["🍗", "🥩", "🥓", "🐟", "🦐", "🌭"]
        case .bakery:      return ["🍞", "🥐", "🥖", "🧁", "🍰", "🥯"]
        case .pantry:      return ["🥫", "🍚", "🍝", "🥚", "☕️", "🧂", "🍪"]
        case .electronics: return ["🔌", "🎧", "📱", "💻", "📺", "🔋", "⌚️"]
        case .home:        return ["🏠", "🛋️", "🍳", "🧹", "🪴", "💡"]
        case .apparel:     return ["👕", "👟", "👖", "👗", "🧥", "👜"]
        }
    }

    var emoji: String { emojiChoices[0] }

    /// A sensible default deadline for a new item in this category:
    /// how long the food usually keeps, or a 30-day return window.
    var typicalDays: Int {
        switch self {
        case .meat:    return 3
        case .produce: return 5
        case .bakery:  return 5
        case .dairy:   return 7
        case .pantry:  return 90
        case .electronics, .home, .apparel: return 30
        }
    }

    static func categories(for type: ItemType) -> [ItemCategory] {
        allCases.filter { $0.isFood == (type == .food) }
    }

    static func defaultCategory(for type: ItemType) -> ItemCategory {
        type == .food ? .dairy : .electronics
    }

    /// Reads a stored category, including names written by the older
    /// version of the app ("Vegetables", "Fruits") that no longer exist.
    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = ItemCategory.fromStored(raw)
    }

    static func fromStored(_ raw: String) -> ItemCategory {
        if let match = ItemCategory(rawValue: raw) { return match }
        switch raw {
        case "Vegetables", "Fruits": return .produce
        default:                     return .pantry
        }
    }
}

enum ItemType: String, Codable, CaseIterable, Identifiable {
    case food = "Food"
    case purchase = "Purchase"

    var id: Self { self }
}

// MARK: - Models

struct PantryItem: Identifiable, Codable {
    /// Also used as the Firestore document ID.
    var id: String = UUID().uuidString
    var name: String
    var emoji: String
    var category: ItemCategory
    var type: ItemType
    var source: String
    var purchasedDate: Date
    /// Food: the expiry date. Purchase: the last day to return it.
    var expiryDate: Date
    var notes: String = ""
    var amount: Double? = nil
    /// Purchases only. nil means no warranty.
    var warrantyDate: Date? = nil
    /// Whether to send a reminder before the deadline.
    var notify: Bool = true
    /// How many are left (12 eggs). nil means it isn't counted.
    var quantity: Int? = nil
    /// Purchases: when "Start Return" was tapped. The item stays on the
    /// list, with its reminder, until it is marked as returned.
    var returnStartedDate: Date? = nil

    enum CodingKeys: String, CodingKey {
        case id, name, emoji, category, type, source,
             purchasedDate, expiryDate, notes, amount, warrantyDate, notify,
             quantity, returnStartedDate
    }

    var isReturning: Bool { type == .purchase && returnStartedDate != nil }

    /// Units left, counting an uncounted item as 1.
    var count: Int { max(quantity ?? 1, 1) }

    // MARK: Dates

    /// Whole days from today to `date`. Negative once it has passed.
    static func days(until date: Date) -> Int {
        let start = Calendar.current.startOfDay(for: Date())
        let end = Calendar.current.startOfDay(for: date)
        return Calendar.current.dateComponents([.day], from: start, to: end).day ?? 0
    }

    /// Days left on the expiry date (food) or return window (purchase).
    var daysLeft: Int { Self.days(until: expiryDate) }

    var warrantyDaysLeft: Int? { warrantyDate.map { Self.days(until: $0) } }

    /// A purchase whose return window has closed but whose warranty
    /// still runs. It stays on the list and counts down the warranty.
    var isUnderWarrantyOnly: Bool {
        guard type == .purchase, daysLeft < 0, let left = warrantyDaysLeft else { return false }
        return left >= 0
    }

    /// Days left on whichever deadline matters right now.
    var activeDaysLeft: Int {
        isUnderWarrantyOnly ? (warrantyDaysLeft ?? daysLeft) : daysLeft
    }

    /// Nothing left to track: the food expired, or the purchase's return
    /// window and warranty have both ended.
    var isExpired: Bool { activeDaysLeft < 0 }

    var expiryLabel: String {
        let left = activeDaysLeft

        if isUnderWarrantyOnly {
            return left == 0 ? "Warranty ends today" : "Warranty · \(left)d left"
        }
        if isReturning && left >= 0 {
            return left == 0 ? "Drop off today" : "Drop off · \(left)d left"
        }
        if left < 0 {
            if type == .purchase { return "Return closed" }
            return left == -1 ? "Expired yesterday" : "Expired \(-left) days ago"
        }
        if left == 0 { return type == .purchase ? "Return by today" : "Expires today" }
        if left == 1 { return "1 day left" }
        return "\(left) days left"
    }

    var urgencyColor: Color {
        if activeDaysLeft <= 0 { return AppTheme.danger }
        if activeDaysLeft <= 3 { return AppTheme.warning }
        if isUnderWarrantyOnly { return AppTheme.violet }
        return AppTheme.sage
    }
}

// MARK: - Reading old documents
/// Items saved by the earlier version of the app used different field
/// names (kind, store, deadline, price). This reads both shapes, so old
/// items keep showing up instead of failing to decode. Saving an item
/// always writes the new shape.
/// Lives in an extension so Swift still generates the memberwise init.
extension PantryItem {
    private enum LegacyKeys: String, CodingKey {
        case kind, store, deadline, price
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let old = try decoder.container(keyedBy: LegacyKeys.self)

        id    = try c.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        name  = try c.decodeIfPresent(String.self, forKey: .name) ?? "Untitled"
        emoji = try c.decodeIfPresent(String.self, forKey: .emoji) ?? "📦"

        category = try c.decodeIfPresent(ItemCategory.self, forKey: .category) ?? .pantry

        let rawType = try c.decodeIfPresent(String.self, forKey: .type)
            ?? old.decodeIfPresent(String.self, forKey: .kind)
            ?? "Food"
        type = rawType.lowercased() == "purchase" ? .purchase : .food

        source = try c.decodeIfPresent(String.self, forKey: .source)
            ?? old.decodeIfPresent(String.self, forKey: .store)
            ?? ""

        let expiry = try c.decodeIfPresent(Date.self, forKey: .expiryDate)
            ?? old.decodeIfPresent(Date.self, forKey: .deadline)
            ?? Date()
        expiryDate = expiry
        purchasedDate = try c.decodeIfPresent(Date.self, forKey: .purchasedDate) ?? expiry

        notes  = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
        amount = try c.decodeIfPresent(Double.self, forKey: .amount)
            ?? old.decodeIfPresent(Double.self, forKey: .price)

        warrantyDate = try c.decodeIfPresent(Date.self, forKey: .warrantyDate)
        notify       = try c.decodeIfPresent(Bool.self, forKey: .notify) ?? true
        quantity     = try c.decodeIfPresent(Int.self, forKey: .quantity)
        returnStartedDate = try c.decodeIfPresent(Date.self, forKey: .returnStartedDate)
    }
}

struct RescueRecipe: Identifiable {
    let id = UUID()
    var name: String
    var emoji: String
    var prepMinutes: Int
    var servings: Int
    var calories: Int
    var ingredients: [String]
    var steps: [String]
}

/// One row in the in-app Notifications screen. Built from the items
/// themselves, so it always matches what is actually expiring.
struct AppNotification: Identifiable {
    /// The item's id, so tapping the row can open that item.
    let id: String
    var emoji: String
    var title: String
    var message: String
    var timeAgo: String
}

// MARK: - Starter data
/// Written to Firestore once, the first time an account signs in.

extension PantryItem {
    static var samples: [PantryItem] {
        let today = Date()
        func days(_ n: Int) -> Date {
            Calendar.current.date(byAdding: .day, value: n, to: today) ?? today
        }

        return [
            PantryItem(name: "Fresh Milk (1L)", emoji: "🥛", category: .dairy, type: .food,
                       source: "Scanned receipt", purchasedDate: days(-5), expiryDate: days(0), amount: 89),
            PantryItem(name: "Spinach", emoji: "🥬", category: .produce, type: .food,
                       source: "Organic Mart", purchasedDate: days(-2), expiryDate: days(2), amount: 65),
            PantryItem(name: "Chicken Breast", emoji: "🍗", category: .meat, type: .food,
                       source: "Purefoods", purchasedDate: days(-1), expiryDate: days(3), amount: 220),
            PantryItem(name: "Wheat Bread", emoji: "🍞", category: .bakery, type: .food,
                       source: "Gardenia", purchasedDate: days(-1), expiryDate: days(6), amount: 95),
            PantryItem(name: "Fresh Eggs", emoji: "🥚", category: .pantry, type: .food,
                       source: "12-pack", purchasedDate: days(-3), expiryDate: days(12), amount: 145),
            PantryItem(name: "Fuji Apples", emoji: "🍎", category: .produce, type: .food,
                       source: "Imported", purchasedDate: days(-2), expiryDate: days(9), amount: 180),
            PantryItem(name: "Ninja Professional Blender", emoji: "🔌", category: .electronics, type: .purchase,
                       source: "Ace Home Center", purchasedDate: days(-28), expiryDate: days(2), amount: 3499,
                       warrantyDate: days(337)),
            PantryItem(name: "Sony Headphones", emoji: "🎧", category: .electronics, type: .purchase,
                       source: "Tech Emporium", purchasedDate: days(-10), expiryDate: days(20), amount: 6990,
                       warrantyDate: days(355))
        ]
    }
}

// MARK: - Store
/// Holds the item list and every action that changes it.
/// Items live in Firestore; this keeps a live local copy that the
/// screens read from.

final class ShelfLifeStore: ObservableObject {
    @Published var items: [PantryItem] = []
    @Published var isLoading = false
    /// The last items deleted, kept for a few seconds so they can be undone.
    @Published var recentlyDeleted: [PantryItem] = []
    /// What happened to past items (used, wasted, returned). Newest first.
    @Published var history: [HistoryEntry] = []
    /// The last save or delete that failed. Shown as a banner.
    @Published var errorMessage: String? = nil

    private let service = FirestoreService()
    private var listener: ListenerRegistration?
    private var historyListener: ListenerRegistration?
    private var userID: String?
    /// The starter-items check runs once per sign-in.
    private var didCheckSeed = false

    init() {
        service.onError = { [weak self] message in
            self?.errorMessage = message
        }
    }

    // MARK: Connecting

    /// Called when someone signs in. Starts watching their items.
    func connect(userID: String) {
        guard self.userID != userID else { return }
        self.userID = userID
        isLoading = true
        ReminderManager.shared.requestPermission()

        historyListener?.remove()
        historyListener = service.listenHistory(userID: userID) { [weak self] entries in
            self?.history = entries.sorted { $0.date > $1.date }
        }

        listener?.remove()
        listener = service.listen(userID: userID) { [weak self] items, isFromCache in
            guard let self else { return }
            self.items = items
            self.isLoading = false
            ReminderManager.shared.reschedule(for: items)
            self.applyNotificationActions()

            // The first snapshot can come from the phone's cache before the
            // server answers. Only decide about starter data once the
            // server has replied, so real items are never mistaken for an
            // empty account.
            guard !isFromCache else { return }
            self.seedIfNeeded(userID: userID, isEmpty: items.isEmpty)
        }
    }

    /// Called on sign-out. Stops listening and clears local data.
    func disconnect() {
        listener?.remove()
        listener = nil
        historyListener?.remove()
        historyListener = nil
        history = []
        userID = nil
        didCheckSeed = false
        items = []
        recentlyDeleted = []
        ReminderManager.shared.removeAll()
    }

    /// Starter items go in once per account. The flag is saved on the
    /// account in Firestore, so emptying your list and then reinstalling
    /// or using a new phone doesn't bring the samples back.
    private func seedIfNeeded(userID: String, isEmpty: Bool) {
        guard !didCheckSeed else { return }
        didCheckSeed = true

        // Older versions kept the flag on the phone. Carry it over.
        let legacyKey = "seeded-\(userID)"
        if UserDefaults.standard.bool(forKey: legacyKey) {
            service.markSeeded(userID: userID)
            return
        }

        service.isSeeded(userID: userID) { [weak self] seeded in
            guard let self, self.userID == userID else { return }
            // nil: couldn't reach the server. Try again next sign-in.
            guard let seeded else { self.didCheckSeed = false; return }
            if seeded { return }
            if isEmpty && self.items.isEmpty {
                self.service.seedSampleData(userID: userID)
            }
            self.service.markSeeded(userID: userID)
        }
    }

    /// Deletes everything this account stored. Listening stops first so
    /// the empty list doesn't trigger the starter items again.
    func deleteAllData(userID: String, completion: @escaping (Error?) -> Void) {
        disconnect()
        service.deleteAllData(userID: userID) { [weak self] error in
            if error != nil {
                // Still signed in, so start showing the items again.
                self?.connect(userID: userID)
            }
            completion(error)
        }
    }

    /// Rebuilds reminders after a setting changes.
    func rescheduleReminders() {
        ReminderManager.shared.reschedule(for: items)
    }

    // MARK: Lists

    var pantryItems: [PantryItem] { items.filter { $0.type == .food } }
    var purchaseItems: [PantryItem] { items.filter { $0.type == .purchase } }

    /// Due today or in the next 3 days. Expired items are listed separately.
    var expiringSoon: [PantryItem] {
        items.filter { (0...3).contains($0.activeDaysLeft) }
            .sorted { $0.activeDaysLeft < $1.activeDaysLeft }
    }

    /// Most recently expired first.
    var expiredItems: [PantryItem] {
        items.filter { $0.isExpired }
            .sorted { $0.activeDaysLeft > $1.activeDaysLeft }
    }

    /// Items due within a week. Expired items don't count: that money is
    /// already gone, not at risk.
    var atRiskItems: [PantryItem] {
        items.filter { (0...7).contains($0.activeDaysLeft) }
    }

    /// Due today or already past. Shown as the app icon badge.
    var dueOrOverdueCount: Int {
        items.filter { $0.activeDaysLeft <= 0 }.count
    }

    var totalAtRisk: Double {
        atRiskItems.reduce(0) { $0 + ($1.amount ?? 0) }
    }

    /// What expired food cost.
    var totalWasted: Double {
        expiredItems.filter { $0.type == .food }.reduce(0) { $0 + ($1.amount ?? 0) }
    }

    // MARK: Notifications screen

    /// Everything due within 3 days, plus anything already expired.
    var notifications: [AppNotification] {
        items.filter { $0.activeDaysLeft <= 3 }
            .sorted { $0.activeDaysLeft < $1.activeDaysLeft }
            .map { item in
                AppNotification(id: item.id,
                                emoji: item.emoji,
                                title: Self.alertTitle(for: item),
                                message: Self.alertMessage(for: item),
                                timeAgo: Self.whenText(item.activeDaysLeft))
            }
    }

    private static func dueText(_ left: Int) -> String {
        if left == 0 { return "today" }
        if left == 1 { return "tomorrow" }
        return "in \(left) days"
    }

    private static func alertTitle(for item: PantryItem) -> String {
        let left = item.activeDaysLeft
        if item.isUnderWarrantyOnly { return "\(item.name) warranty ends \(dueText(left))" }
        if item.isReturning && left >= 0 {
            return "Drop off \(item.name) \(dueText(left))"
        }
        if item.type == .purchase {
            return left < 0 ? "Return window closed for \(item.name)"
                            : "\(item.name) return window closes \(dueText(left))"
        }
        return left < 0 ? "\(item.name) has expired" : "\(item.name) expires \(dueText(left))"
    }

    private static func alertMessage(for item: PantryItem) -> String {
        if item.isUnderWarrantyOnly { return "File any repair or replacement claim before it ends." }
        if item.isReturning && !item.isExpired {
            return "Return started. Mark it returned once it's dropped off."
        }
        if item.type == .purchase {
            return item.isExpired ? "You can delete it if you're keeping it."
                                  : "Start the return if you're not keeping it."
        }
        return item.isExpired ? "Check it, then mark it used or delete it."
                              : "Use it soon. Rescue Recipes has ideas."
    }

    private static func whenText(_ left: Int) -> String {
        if left < 0 { return "\(-left)d ago" }
        if left == 0 { return "Today" }
        if left == 1 { return "Tomorrow" }
        return "In \(left)d"
    }

    // MARK: Actions
    // Each writes to Firestore. The listener then updates `items`, so the
    // screens refresh on their own.

    func addItem(_ item: PantryItem) {
        guard let userID else { return }
        service.save(item, userID: userID)
    }

    func updateItem(_ item: PantryItem) {
        guard let userID else { return }
        service.save(item, userID: userID)
    }

    func deleteItem(_ item: PantryItem) {
        deleteItems([item])
    }

    /// Deletes and remembers the items so the Undo bar can put them back.
    /// Also writes a history entry: the given outcome, or "wasted" when
    /// expired food is deleted. Other deletes leave no history.
    func deleteItems(_ toDelete: [PantryItem], outcome: HistoryOutcome? = nil) {
        guard let userID, !toDelete.isEmpty else { return }
        for item in toDelete {
            service.delete(item, userID: userID)

            let result = outcome ?? ((item.type == .food && item.isExpired) ? .wasted : nil)
            if let result {
                service.saveHistory(HistoryEntry(item: item, outcome: result), userID: userID)
            }
        }
        recentlyDeleted = toDelete
    }

    /// Writes the deleted items back with the same ids, and removes the
    /// history entries the delete created.
    func undoDelete() {
        guard let userID else { return }
        for item in recentlyDeleted {
            service.save(item, userID: userID)
            service.deleteHistory(id: item.id, userID: userID)
        }
        recentlyDeleted = []
    }

    /// Hides the Undo bar, unless a newer delete has replaced it.
    func clearUndo(ifMatching ids: [String]) {
        if recentlyDeleted.map(\.id) == ids {
            recentlyDeleted = []
        }
    }

    /// Using all of an item takes it off the list.
    func markUsed(_ item: PantryItem) { deleteItems([item], outcome: .used) }

    /// Uses one of several (1 of 12 eggs). Logs that one as used and
    /// keeps the rest, with the price split per unit.
    func useOne(_ item: PantryItem) {
        guard item.count > 1, let userID else {
            markUsed(item)
            return
        }
        let perUnit = item.amount.map { $0 / Double(item.count) }

        var used = HistoryEntry(item: item, outcome: .used)
        used.id = "\(item.id)-\(UUID().uuidString)"
        used.amount = perUnit
        service.saveHistory(used, userID: userID)

        var rest = item
        rest.quantity = item.count - 1
        rest.amount = perUnit.map { $0 * Double(item.count - 1) }
        updateItem(rest)
    }

    /// Starting a return keeps the item, and its reminder, on the list
    /// until it is marked as returned.
    func startReturn(_ item: PantryItem) {
        var updated = item
        updated.returnStartedDate = Date()
        updateItem(updated)
    }

    func cancelReturn(_ item: PantryItem) {
        var updated = item
        updated.returnStartedDate = nil
        updateItem(updated)
    }

    /// Dropped off: takes it off the list and logs it as returned.
    func completeReturn(_ item: PantryItem) { deleteItems([item], outcome: .returned) }

    // MARK: Notification buttons

    /// Runs "Mark used" / "+3 days" taps from reminders once the item has
    /// loaded. Taps can arrive before sign-in finishes restoring.
    private func applyNotificationActions() {
        for action in ReminderManager.shared.pendingActions {
            guard let item = items.first(where: { $0.id == action.itemID }) else { continue }
            switch action.kind {
            case .markUsed:
                if item.count > 1 { useOne(item) } else { markUsed(item) }
            case .extend3:
                extend(item, byDays: 3)
            }
            ReminderManager.shared.pendingActions.removeAll { $0.itemID == action.itemID }
        }
    }

    // MARK: History numbers

    private func historyTotal(_ outcome: HistoryOutcome) -> Double {
        history.filter { $0.outcome == outcome }.reduce(0) { $0 + ($1.amount ?? 0) }
    }

    /// Value of food used before it expired.
    var totalSaved: Double { historyTotal(.used) }
    /// Value of food that expired and was thrown away.
    var totalWastedHistory: Double { historyTotal(.wasted) }
    /// Value of purchases returned in time.
    var totalReturned: Double { historyTotal(.returned) }

    var usedCount: Int { history.filter { $0.outcome == .used }.count }
    var wastedCount: Int { history.filter { $0.outcome == .wasted }.count }

    /// Share of finished food items that were used, 0...1. nil with no history.
    var usedRate: Double? {
        let total = usedCount + wastedCount
        return total == 0 ? nil : Double(usedCount) / Double(total)
    }

    /// Used and wasted value for each of the last 6 months, oldest first.
    var monthlyHistory: [MonthSummary] {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"

        guard let thisMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: Date()))
        else { return [] }

        return (0..<6).reversed().compactMap { back in
            guard let start = calendar.date(byAdding: .month, value: -back, to: thisMonth),
                  let end = calendar.date(byAdding: .month, value: 1, to: start) else { return nil }
            let entries = history.filter { $0.date >= start && $0.date < end }
            func sum(_ outcome: HistoryOutcome) -> Double {
                entries.filter { $0.outcome == outcome }.reduce(0) { $0 + ($1.amount ?? 0) }
            }
            return MonthSummary(id: start, label: formatter.string(from: start),
                                used: sum(.used), wasted: sum(.wasted))
        }
    }

    /// Pushes the expiry date back. An already-expired item is extended
    /// from today, so "+3 days" always means 3 days from now or later.
    func extend(_ item: PantryItem, byDays days: Int) {
        var updated = item
        let base = item.daysLeft < 0 ? Date() : item.expiryDate
        updated.expiryDate = Calendar.current.date(byAdding: .day, value: days, to: base) ?? base
        updateItem(updated)
    }

    // MARK: Export

    /// Writes every item to a CSV file (opens in Numbers, Excel or Sheets)
    /// and returns where it was saved.
    func exportCSV() -> URL? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        func field(_ text: String) -> String {
            "\"" + text.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }

        var lines = ["Name,Type,Category,Store,Purchased,Expiry or return date,Warranty until,Quantity,Price (\(Money.code)),Notes"]
        for item in items.sorted(by: { $0.expiryDate < $1.expiryDate }) {
            lines.append([
                field(item.name),
                item.type.rawValue,
                item.category.rawValue,
                field(item.source),
                formatter.string(from: item.purchasedDate),
                formatter.string(from: item.expiryDate),
                item.warrantyDate.map { formatter.string(from: $0) } ?? "",
                item.quantity.map(String.init) ?? "",
                item.amount.map { String(format: "%.2f", $0) } ?? "",
                field(item.notes)
            ].joined(separator: ","))
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ShelfLife-export.csv")
        do {
            try lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            print("Export failed:", error.localizedDescription)
            return nil
        }
    }

    // MARK: Recipes

    /// Two simple recipes per food category, built around the item.
    func recipes(for item: PantryItem) -> [RescueRecipe] {
        let name = item.name.lowercased()

        // The templates pour the item in by the cup, so they only suit
        // some items: milk pancakes need milk, a smoothie needs fruit.
        // Anything else gets the general recipes at the bottom.
        func mentions(_ words: [String]) -> Bool {
            words.contains { name.contains($0) }
        }
        let isMilky = mentions(["milk", "gatas", "cream", "yogurt", "yoghurt"])
        let isFruit = mentions(["apple", "banana", "saging", "mango", "mangga", "orange", "grape",
                                "berry", "berries", "pineapple", "papaya", "melon", "fruit", "pear",
                                "kiwi", "peach", "avocado", "calamansi"])

        switch item.category {
        case .dairy where isMilky:
            return [
                RescueRecipe(name: "Milk Pancakes", emoji: "🥞", prepMinutes: 15, servings: 2, calories: 310,
                             ingredients: ["1 cup \(name)", "2 eggs", "1½ cups flour",
                                           "2 tbsp sugar", "1 tsp baking powder", "pinch of salt"],
                             steps: ["Mix the dry ingredients", "Whisk in the \(name) and eggs",
                                     "Rest the batter for 5 minutes", "Cook on medium heat until bubbles form, then flip",
                                     "Serve with honey or fruit"]),
                RescueRecipe(name: "Quick Leche Flan", emoji: "🍮", prepMinutes: 40, servings: 4, calories: 280,
                             ingredients: ["1 cup \(name)", "4 egg yolks", "½ cup condensed milk",
                                           "1 tsp vanilla", "½ cup sugar for caramel"],
                             steps: ["Melt the sugar into caramel in the llanera", "Whisk the yolks, \(name), condensed milk and vanilla",
                                     "Strain the mix over the caramel", "Cover with foil and steam for 30 minutes",
                                     "Chill, then flip onto a plate"])
            ]
        case .produce where isFruit:
            return [
                RescueRecipe(name: "Fruit Smoothie", emoji: "🥤", prepMinutes: 5, servings: 2, calories: 180,
                             ingredients: ["1 cup \(name), chopped", "1 banana", "1 cup milk or yogurt",
                                           "1 tbsp honey", "a handful of ice"],
                             steps: ["Put everything in the blender", "Blend until smooth", "Taste and add honey if needed",
                                     "Drink right away"]),
                RescueRecipe(name: "Fruit Salad", emoji: "🍧", prepMinutes: 10, servings: 4, calories: 220,
                             ingredients: ["2 cups \(name), diced", "1 cup other fruit you have", "½ cup all-purpose cream",
                                           "¼ cup condensed milk"],
                             steps: ["Dice the fruit into bite-size pieces", "Fold in the cream and condensed milk",
                                     "Chill for at least 30 minutes", "Serve cold"])
            ]
        case .produce:
            return [
                RescueRecipe(name: "Ginisang Gulay", emoji: "🥘", prepMinutes: 15, servings: 3, calories: 150,
                             ingredients: ["2 cups \(name), chopped", "3 cloves garlic", "1 onion",
                                           "1 tbsp oyster sauce", "1 tbsp oil", "salt and pepper"],
                             steps: ["Sauté the garlic and onion in oil", "Add the \(name) and stir-fry for 3–4 minutes",
                                     "Season with oyster sauce, salt and pepper", "Serve hot with rice"]),
                RescueRecipe(name: "Sinabawang Gulay", emoji: "🍲", prepMinutes: 25, servings: 4, calories: 140,
                             ingredients: ["2 cups \(name), chopped", "1 onion", "2 cloves garlic", "1 thumb ginger",
                                           "4 cups water or broth", "fish sauce to taste"],
                             steps: ["Sauté the garlic, onion and ginger", "Pour in the water and bring to a boil",
                                     "Add the \(name) and simmer until tender", "Season with fish sauce and serve hot"])
            ]
        case .meat:
            return [
                RescueRecipe(name: "Simple Adobo", emoji: "🍲", prepMinutes: 45, servings: 4, calories: 420,
                             ingredients: ["500 g \(name)", "⅓ cup soy sauce", "¼ cup vinegar",
                                           "1 head garlic, crushed", "3 bay leaves", "1 tsp peppercorns"],
                             steps: ["Combine everything in a pot and marinate for 15 minutes",
                                     "Bring to a boil, then simmer covered for 30 minutes",
                                     "Uncover and reduce the sauce", "Serve with rice"]),
                RescueRecipe(name: "Leftover Fried Rice", emoji: "🍳", prepMinutes: 15, servings: 2, calories: 450,
                             ingredients: ["1 cup cooked \(name), diced", "2 cups day-old rice", "2 eggs",
                                           "3 cloves garlic", "1 tbsp soy sauce", "spring onions"],
                             steps: ["Fry the garlic until golden", "Add the \(name) and cook through",
                                     "Push aside, scramble the eggs", "Add the rice and soy sauce and toss well",
                                     "Top with spring onions"])
            ]
        case .bakery:
            return [
                RescueRecipe(name: "French Toast", emoji: "🍞", prepMinutes: 10, servings: 2, calories: 330,
                             ingredients: ["4 slices \(name)", "2 eggs", "½ cup milk",
                                           "1 tsp cinnamon", "1 tbsp butter"],
                             steps: ["Whisk the eggs, milk and cinnamon", "Dip each slice on both sides",
                                     "Fry in butter until golden", "Serve with syrup or fruit"]),
                RescueRecipe(name: "Bread Pudding", emoji: "🍮", prepMinutes: 45, servings: 4, calories: 360,
                             ingredients: ["4 cups \(name), cubed", "2 cups milk", "3 eggs",
                                           "½ cup sugar", "1 tsp vanilla", "raisins (optional)"],
                             steps: ["Soak the bread in milk for 10 minutes", "Mix in the eggs, sugar and vanilla",
                                     "Pour into a greased dish", "Bake at 180°C for 35 minutes"])
            ]
        default:
            return [
                RescueRecipe(name: "Clean-Out Omelette", emoji: "🍳", prepMinutes: 10, servings: 1, calories: 290,
                             ingredients: ["3 eggs", "½ cup \(name)", "1 tbsp milk",
                                           "salt and pepper", "1 tsp oil"],
                             steps: ["Beat the eggs with milk, salt and pepper", "Cook the \(name) in oil for a minute",
                                     "Pour in the eggs and cook gently", "Fold and serve"]),
                RescueRecipe(name: "Garlic Sinangag Bowl", emoji: "🍚", prepMinutes: 15, servings: 2, calories: 400,
                             ingredients: ["2 cups day-old rice", "½ cup \(name)", "5 cloves garlic",
                                           "1 egg", "salt"],
                             steps: ["Fry the garlic until golden", "Add the rice and \(name) and toss",
                                     "Season with salt", "Top with a fried egg"])
            ]
        }
    }
}
