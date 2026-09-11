//
//  AuthService.swift
//  ShelfLIFE
//
//  Created by Mac-LAB on 9/7/26.
//

import SwiftUI
import Combine
import FirebaseFirestore

// MARK: - Shared app data
/// Holds every item and all the logic that changes them.
/// Items live in Firestore; this class keeps a live local copy.
class AppData: ObservableObject {

    @Published var items: [ShelfItem] = []
    @Published var hasStarted = false
    @Published var isLoading = false

    // Settings
    @Published var notificationsOn = true
    @Published var autoDetectOn = true
    @Published var iCloudOn = true

    // Vault screen
    @Published var searchText = ""
    @Published var selectedKind: ItemKind = .food

    private let service = DataService()
    private var listener: ListenerRegistration?
    private var userID: String?

    // MARK: - Connecting to Firestore

    /// Called when someone signs in. Starts watching their items.
    func connect(userID: String) {
        guard self.userID != userID else { return }
        self.userID = userID
        isLoading = true

        listener?.remove()
        listener = service.listen(userID: userID) { [weak self] items in
            guard let self else { return }
            self.items = items
            self.isLoading = false

            // A brand new account starts empty — give it the samples.
            if items.isEmpty {
                self.service.seedSampleData(userID: userID)
            }
        }
    }

    /// Called on sign-out. Stops listening and clears local data.
    func disconnect() {
        listener?.remove()
        listener = nil
        userID = nil
        items = []
        hasStarted = false
    }

    // MARK: - Lists

    /// Items still waiting on a decision, soonest deadline first.
    var activeItems: [ShelfItem] {
        items.filter { !$0.isDone }
             .sorted { $0.daysLeft < $1.daysLeft }
    }

    /// The five most urgent items, shown on the Home screen.
    var expiringSoon: [ShelfItem] {
        Array(activeItems.prefix(5))
    }

    var foodItems: [ShelfItem] {
        activeItems.filter { $0.kind == .food }
    }

    var purchaseItems: [ShelfItem] {
        activeItems.filter { $0.kind == .purchase }
    }

    /// What the Vault shows: the chosen tab, narrowed by the search box.
    var vaultItems: [ShelfItem] {
        let list = selectedKind == .food ? foodItems : purchaseItems
        if searchText.isEmpty { return list }
        return list.filter {
            $0.name.lowercased().contains(searchText.lowercased())
        }
    }

    // MARK: - Numbers

    /// Total value of everything due within three days.
    var moneyAtRisk: Double {
        activeItems.filter { $0.daysLeft <= 3 }
                   .reduce(0) { $0 + $1.price }
    }

    var atRiskCount: Int {
        activeItems.filter { $0.daysLeft <= 3 }.count
    }

    var savedTotal: Double {
        items.filter { $0.isDone }.reduce(0) { $0 + $1.price }
    }

    var doneCount: Int {
        items.filter { $0.isDone }.count
    }

    /// Spending per category, biggest first.
    var spending: [(name: String, total: Double)] {
        let purchases = items.filter { $0.kind == .purchase }
        let groups = Dictionary(grouping: purchases) { $0.category }
        return groups.map { (name: $0.key, total: $0.value.reduce(0) { $0 + $1.price }) }
                     .sorted { $0.total > $1.total }
    }

    var riskSummary: String {
        let food = activeItems.filter { $0.kind == .food && $0.daysLeft <= 3 }.count
        let buys = activeItems.filter { $0.kind == .purchase && $0.daysLeft <= 3 }.count
        return "\(food) food expiring · \(buys) window closing"
    }

    // MARK: - Actions
    // Each one writes to Firestore. The listener then updates `items`,
    // so the screen refreshes on its own.

    func start() {
        hasStarted = true
    }

    /// Marks food as used, or a purchase as decided.
    func markDone(_ item: ShelfItem) {
        guard let userID else { return }
        var copy = item
        copy.isDone = true
        service.save(copy, userID: userID)
    }

    func undo(_ item: ShelfItem) {
        guard let userID else { return }
        var copy = item
        copy.isDone = false
        service.save(copy, userID: userID)
    }

    func delete(_ item: ShelfItem) {
        guard let userID else { return }
        service.delete(item, userID: userID)
    }

    func add(name: String, kind: ItemKind, category: String,
             store: String, days: Int, price: Double) {
        guard let userID else { return }

        let clean = name.trimmingCharacters(in: .whitespaces)
        guard !clean.isEmpty else { return }

        let item = ShelfItem(
            name: clean,
            emoji: kind == .food ? "🍽️" : "🧾",
            kind: kind,
            category: category,
            store: store.isEmpty ? (kind == .food ? "Pantry" : "Added by hand") : store,
            deadline: SampleData.inDays(days),
            price: price
        )
        service.save(item, userID: userID)
    }

    func reset() {
        guard let userID else { return }
        for item in items {
            service.delete(item, userID: userID)
        }
        service.seedSampleData(userID: userID)
    }
}
