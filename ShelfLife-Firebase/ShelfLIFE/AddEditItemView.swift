import SwiftUI
import Foundation

/// Adds a new item, or edits one when `editing` is passed in.
/// Built from glass sections rather than `Form`, which paints opaque
/// grouped rows over the aurora.
struct AddEditItemView: View {
    @EnvironmentObject var store: ShelfLifeStore
    @Environment(\.dismiss) private var dismiss

    /// nil = adding a new item. Otherwise the item being edited.
    let editing: PantryItem?

    @State private var itemName: String
    @State private var selectedType: ItemType
    @State private var selectedCategory: ItemCategory
    @State private var emoji: String
    /// Once the user taps an emoji, changing category stops replacing it.
    @State private var emojiPickedByHand: Bool
    @State private var expiryDate: Date
    @State private var hasWarranty: Bool
    @State private var warrantyDate: Date
    @State private var amountText: String
    @State private var notes: String
    @State private var notifyMe: Bool

    init(editing: PantryItem? = nil) {
        self.editing = editing

        let type = editing?.type ?? .food
        let category = editing?.category ?? ItemCategory.defaultCategory(for: type)
        let inAWeek = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
        let inAYear = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()

        _itemName          = State(initialValue: editing?.name ?? "")
        _selectedType      = State(initialValue: type)
        _selectedCategory  = State(initialValue: category)
        _emoji             = State(initialValue: editing?.emoji ?? category.emoji)
        _emojiPickedByHand = State(initialValue: editing != nil)
        _expiryDate        = State(initialValue: editing?.expiryDate ?? inAWeek)
        _hasWarranty       = State(initialValue: editing?.warrantyDate != nil)
        _warrantyDate      = State(initialValue: editing?.warrantyDate ?? inAYear)
        _notes             = State(initialValue: editing?.notes ?? "")
        _notifyMe          = State(initialValue: editing?.notify ?? true)

        // Show a whole number without ".0" (3499 instead of 3499.0).
        if let amount = editing?.amount {
            _amountText = State(initialValue: amount == amount.rounded()
                                ? String(Int(amount)) : String(amount))
        } else {
            _amountText = State(initialValue: "")
        }
    }

    private var isEditing: Bool { editing != nil }

    private var canSave: Bool {
        !itemName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// The typed price as a number. Empty or invalid text means no price.
    private var amount: Double? {
        let cleaned = amountText.replacingOccurrences(of: ",", with: "")
        guard let value = Double(cleaned), value > 0 else { return nil }
        return value
    }

    /// Food shows food categories, purchases show purchase categories.
    /// An older item saved under a mismatched category keeps it visible.
    private var categoryOptions: [ItemCategory] {
        let options = ItemCategory.categories(for: selectedType)
        return options.contains(selectedCategory) ? options : options + [selectedCategory]
    }

    /// The category's emojis, plus the current one if it isn't among them.
    private var emojiOptions: [String] {
        let options = selectedCategory.emojiChoices
        return options.contains(emoji) ? options : [emoji] + options
    }

    /// Quick date buttons: (label, days from today).
    private var quickDates: [(String, Int)] {
        selectedType == .food
            ? [("3 days", 3), ("1 week", 7), ("2 weeks", 14), ("1 month", 30)]
            : [("7 days", 7), ("15 days", 15), ("30 days", 30)]
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    GlassSection("Item name") {
                        TextField("e.g. Greek Yogurt", text: $itemName)
                            .font(.subheadline)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 15)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        sectionLabel("Type")
                        GlassSegmentedControl(
                            selection: $selectedType,
                            options: [(.food, "Food"), (.purchase, "Purchase")]
                        )
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        sectionLabel("Category")
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(categoryOptions) { category in
                                    Button {
                                        withAnimation(.easeOut(duration: 0.15)) {
                                            selectedCategory = category
                                        }
                                    } label: {
                                        CategoryChipView(category: category,
                                                         isSelected: selectedCategory == category)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 6)
                            .padding(.horizontal, 2)
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        sectionLabel("Icon")
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(emojiOptions, id: \.self) { option in
                                    emojiButton(option)
                                }
                            }
                            .padding(.vertical, 6)
                            .padding(.horizontal, 2)
                        }
                    }

                    GlassSection("Price (optional)") {
                        HStack(spacing: 8) {
                            Text(Money.symbol)
                                .font(.subheadline).fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                            TextField("0", text: $amountText)
                                .font(.subheadline)
                                .keyboardType(.decimalPad)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 15)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        sectionLabel(selectedType == .food ? "Expires in" : "Return window")
                        ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(quickDates.indices, id: \.self) { index in
                                let label = quickDates[index].0
                                let days = quickDates[index].1
                                Button {
                                    expiryDate = Calendar.current.date(byAdding: .day, value: days, to: Date()) ?? Date()
                                } label: {
                                    FilterChip(title: label,
                                               isSelected: PantryItem.days(until: expiryDate) == days)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 2)
                        }

                        VStack(spacing: 0) {
                            DatePicker(selectedType == .food ? "Expiry date" : "Last day to return",
                                       selection: $expiryDate, displayedComponents: .date)
                                .font(.subheadline)
                                .tint(AppTheme.sage)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 9)
                        }
                        .glass(cornerRadius: AppTheme.cardRadius)
                    }

                    if selectedType == .purchase {
                        GlassSection("Warranty") {
                            Toggle("Has a warranty", isOn: $hasWarranty.animation())
                                .font(.subheadline)
                                .tint(AppTheme.sage)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 11)

                            if hasWarranty {
                                GlassDivider()
                                DatePicker("Warranty until", selection: $warrantyDate,
                                           in: expiryDate..., displayedComponents: .date)
                                    .font(.subheadline)
                                    .tint(AppTheme.sage)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 9)
                            }
                        }
                    }

                    GlassSection("Reminders") {
                        Toggle(selectedType == .food ? "Remind me before it expires"
                                                     : "Remind me before the deadlines",
                               isOn: $notifyMe)
                            .font(.subheadline)
                            .tint(AppTheme.sage)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 11)
                    }

                    GlassSection("Notes (optional)") {
                        TextField("Add any details…", text: $notes, axis: .vertical)
                            .font(.subheadline)
                            .lineLimit(3...5)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 15)
                    }

                    Button(isEditing ? "Save Changes" : "Save Item") { saveItem() }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(!canSave)
                        .opacity(canSave ? 1 : 0.5)
                        .padding(.top, 4)
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .padding(.bottom, 30)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(isEditing ? "Edit Item" : "Add Item")
            .navigationBarTitleDisplayMode(.inline)
            .transparentChrome()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                        .buttonStyle(GlassIconButtonStyle(size: 34))
                        .accessibilityLabel("Close")
                }
            }
            .onChange(of: selectedType) { _, newType in
                // Switching Food ↔ Purchase moves to a matching category.
                if !ItemCategory.categories(for: newType).contains(selectedCategory) {
                    selectedCategory = ItemCategory.defaultCategory(for: newType)
                }
                if newType == .food { hasWarranty = false }
            }
            .onChange(of: selectedCategory) { _, newCategory in
                if !emojiPickedByHand { emoji = newCategory.emoji }
            }
        }
    }

    private func emojiButton(_ option: String) -> some View {
        let isSelected = option == emoji
        return Button {
            emoji = option
            emojiPickedByHand = true
        } label: {
            Text(option)
                .font(.system(size: 22))
                .frame(width: 46, height: 46)
                .background {
                    Circle().fill(isSelected ? AppTheme.sage.opacity(0.25) : Color.clear)
                    Circle().fill(.ultraThinMaterial).opacity(isSelected ? 0 : 1)
                }
                .overlay {
                    Circle().strokeBorder(isSelected ? AppTheme.sage : Color.white.opacity(0.3),
                                          lineWidth: isSelected ? 2 : 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Icon \(option)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.caption2).fontWeight(.semibold)
            .tracking(0.8)
            .foregroundStyle(.secondary)
            .padding(.leading, 6)
    }

    private func saveItem() {
        let name = itemName.trimmingCharacters(in: .whitespaces)
        let warranty = (selectedType == .purchase && hasWarranty) ? warrantyDate : nil

        if var item = editing {
            // Same id, so Firestore overwrites the same document.
            item.name = name
            item.emoji = emoji
            item.type = selectedType
            item.category = selectedCategory
            item.expiryDate = expiryDate
            item.warrantyDate = warranty
            item.amount = amount
            item.notes = notes
            item.notify = notifyMe
            store.updateItem(item)
        } else {
            let item = PantryItem(
                name: name,
                emoji: emoji,
                category: selectedCategory,
                type: selectedType,
                source: "Added manually",
                purchasedDate: Date(),
                expiryDate: expiryDate,
                notes: notes,
                amount: amount,
                warrantyDate: warranty,
                notify: notifyMe
            )
            store.addItem(item)
        }
        dismiss()
    }
}
