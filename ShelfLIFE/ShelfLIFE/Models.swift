//
//  AuthService.swift
//  ShelfLIFE
//
//  Created by Mac-LAB on 9/7/26.
//

import SwiftUI

// MARK: - Kind of item
enum ItemKind: String, Codable, CaseIterable, Identifiable {
    case food = "Food"
    case purchase = "Purchase"

    var id: String { rawValue }
    var emoji: String { self == .food ? "🥬" : "🧾" }
}

// MARK: - One tracked item
/// Food and purchases use the same type. `kind` decides how the app
/// talks about it: food "expires", a purchase's return window "closes".
struct ShelfItem: Identifiable, Codable {
    var id: String = UUID().uuidString
    var name: String
    var emoji: String
    var kind: ItemKind
    var category: String
    var store: String
    var deadline: Date
    var price: Double
    var isDone = false

    /// Days until the deadline. 0 means today, negative means overdue.
    var daysLeft: Int {
        let cal = Calendar.current
        let from = cal.startOfDay(for: Date())
        let to = cal.startOfDay(for: deadline)
        return cal.dateComponents([.day], from: from, to: to).day ?? 0
    }

    var deadlineText: String {
        if daysLeft < 0 { return "Overdue" }
        if daysLeft == 0 { return kind == .food ? "Expires today" : "Closes today" }
        if daysLeft == 1 { return "1 day left" }
        return "\(daysLeft) days left"
    }

    /// Red when it is due, orange when it is close, green otherwise.
    var color: Color {
        if daysLeft <= 0 { return AppColor.red }
        if daysLeft <= 3 { return AppColor.orange }
        return AppColor.green
    }

    var priceText: String {
        "₱" + String(format: "%.0f", price)
    }

    var dateText: String {
        deadline.formatted(date: .abbreviated, time: .omitted)
    }
}

// MARK: - Recipe
struct Recipe: Identifiable {
    let id = UUID()
    var emoji: String
    var name: String
    var minutes: Int
    var ingredients: [String]
    var steps: [String]
}

// MARK: - Sample data
enum SampleData {

    static func inDays(_ days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: Date()) ?? Date()
    }

    static let items: [ShelfItem] = [
        ShelfItem(name: "Fresh Milk", emoji: "🥛", kind: .food,
                  category: "Dairy", store: "Pantry",
                  deadline: inDays(0), price: 89),
        ShelfItem(name: "Spinach", emoji: "🥬", kind: .food,
                  category: "Vegetables", store: "Pantry",
                  deadline: inDays(2), price: 65),
        ShelfItem(name: "Chicken Breast", emoji: "🍗", kind: .food,
                  category: "Meat", store: "Pantry",
                  deadline: inDays(3), price: 220),
        ShelfItem(name: "Wheat Bread", emoji: "🍞", kind: .food,
                  category: "Bakery", store: "Pantry",
                  deadline: inDays(6), price: 95),
        ShelfItem(name: "Eggs", emoji: "🥚", kind: .food,
                  category: "Dairy", store: "Pantry",
                  deadline: inDays(12), price: 145),
        ShelfItem(name: "Apples", emoji: "🍎", kind: .food,
                  category: "Fruits", store: "Pantry",
                  deadline: inDays(9), price: 180),

        ShelfItem(name: "Ninja Blender", emoji: "🧾", kind: .purchase,
                  category: "Home", store: "Ace Home Center",
                  deadline: inDays(2), price: 3499),
        ShelfItem(name: "Running Shoes", emoji: "👟", kind: .purchase,
                  category: "Apparel", store: "Sports Central",
                  deadline: inDays(1), price: 1290),
        ShelfItem(name: "Sony Headphones", emoji: "🎧", kind: .purchase,
                  category: "Electronics", store: "Digital Hub",
                  deadline: inDays(28), price: 4120),
        ShelfItem(name: "Air Fryer", emoji: "🍟", kind: .purchase,
                  category: "Home", store: "Ace Home Center",
                  deadline: inDays(120), price: 2050),
    ]

    static let recipes: [Recipe] = [
        Recipe(emoji: "🥞", name: "Pancakes", minutes: 15,
               ingredients: ["1 cup milk", "1 cup flour", "1 egg",
                             "2 tbsp sugar", "1 tsp baking powder"],
               steps: ["Mix the dry ingredients.",
                       "Beat the egg into the milk.",
                       "Combine and stir until just mixed.",
                       "Cook 2 minutes per side on a buttered pan."]),
        Recipe(emoji: "🍮", name: "Quick Custard", minutes: 20,
               ingredients: ["2 cups milk", "3 egg yolks", "1/3 cup sugar"],
               steps: ["Warm the milk gently.",
                       "Whisk the yolks and sugar.",
                       "Combine over low heat until it thickens.",
                       "Chill before serving."]),
        Recipe(emoji: "🥗", name: "Garlic Sauté", minutes: 10,
               ingredients: ["1 bunch greens", "3 garlic cloves", "Olive oil"],
               steps: ["Slice the garlic.",
                       "Soften it in warm oil.",
                       "Add the greens and toss until wilted."]),
    ]

    /// Which recipes can use up a given item.
    static func recipes(for item: ShelfItem) -> [Recipe] {
        if item.category == "Dairy" { return [recipes[0], recipes[1]] }
        if item.category == "Vegetables" { return [recipes[2]] }
        return [recipes[0]]
    }
}
