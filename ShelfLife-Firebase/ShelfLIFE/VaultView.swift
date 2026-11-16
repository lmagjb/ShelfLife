import SwiftUI

enum VaultSort: String, CaseIterable, Identifiable {
    case soonest = "Soonest first"
    case name    = "Name (A–Z)"
    case price   = "Price (high to low)"

    var id: Self { self }
}

struct VaultView: View {
    @EnvironmentObject var store: ShelfLifeStore
    @State private var selectedSegment: ItemType = .food
    @State private var searchText = ""
    @State private var isShowingAddItem = false
    @State private var sort: VaultSort = .soonest
    /// nil = all categories.
    @State private var categoryFilter: ItemCategory? = nil
    @State private var isShowingClearExpired = false

    private var segmentItems: [PantryItem] {
        selectedSegment == .food ? store.pantryItems : store.purchaseItems
    }

    /// Only categories that actually have items in this tab get a chip.
    private var availableCategories: [ItemCategory] {
        ItemCategory.allCases.filter { category in
            segmentItems.contains { $0.category == category }
        }
    }

    private var filteredItems: [PantryItem] {
        var result = segmentItems
        if let categoryFilter {
            result = result.filter { $0.category == categoryFilter }
        }
        if !searchText.isEmpty {
            result = result.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        switch sort {
        case .soonest: return result.sorted { $0.activeDaysLeft < $1.activeDaysLeft }
        case .name:    return result.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .price:   return result.sorted { ($0.amount ?? 0) > ($1.amount ?? 0) }
        }
    }

    private var expiredItems: [PantryItem] { filteredItems.filter { $0.isExpired } }
    private var activeItems: [PantryItem]  { filteredItems.filter { !$0.isExpired } }

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                GlassSegmentedControl(
                    selection: $selectedSegment,
                    options: [
                        (.food, "Pantry (\(store.pantryItems.count))"),
                        (.purchase, "Purchases (\(store.purchaseItems.count))")
                    ]
                )
                .padding(.horizontal, 18)

                SearchBarView(
                    text: $searchText,
                    placeholder: selectedSegment == .food ? "Search pantry…" : "Search purchases…"
                )
                .padding(.horizontal, 18)

                if availableCategories.count > 1 {
                    categoryChips
                }

                if filteredItems.isEmpty {
                    Spacer()
                    emptyState
                    Spacer()
                } else {
                    itemList
                }
            }
            .padding(.top, 4)
            .navigationTitle("Vault")
            .transparentChrome()
            .navigationDestination(for: String.self) { id in
                if let item = store.items.first(where: { $0.id == id }) {
                    ItemDetailView(item: item)
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    sortMenu

                    Button { isShowingAddItem = true } label: {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(GlassIconButtonStyle())
                    .accessibilityLabel("Add item")
                }
            }
            .sheet(isPresented: $isShowingAddItem) {
                AddEditItemView()
            }
            .onChange(of: selectedSegment) {
                // A category from the other tab would show nothing.
                categoryFilter = nil
            }
            .confirmationDialog("Delete \(expiredItems.count) expired \(expiredItems.count == 1 ? "item" : "items")?",
                                isPresented: $isShowingClearExpired,
                                titleVisibility: .visible) {
                Button("Delete All", role: .destructive) {
                    store.deleteItems(expiredItems)
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("You can undo this for a few seconds afterwards.")
            }
        }
    }

    // MARK: List
    // `List` is needed for swipe actions. Its rows and separators are made
    // clear so the glass rows still sit straight on the aurora.

    private var itemList: some View {
        List {
            if !expiredItems.isEmpty {
                listHeader(title: "Expired (\(expiredItems.count))",
                           tint: AppTheme.danger,
                           actionTitle: "Clear all") {
                    isShowingClearExpired = true
                }
                ForEach(expiredItems) { item in
                    itemRow(item)
                }

                if !activeItems.isEmpty {
                    listHeader(title: "Tracking (\(activeItems.count))", tint: .secondary)
                }
            }

            ForEach(activeItems) { item in
                itemRow(item)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .scrollIndicators(.hidden)
        .contentMargins(.bottom, 110, for: .scrollContent)
    }

    private func itemRow(_ item: PantryItem) -> some View {
        ZStack {
            // Hidden link: makes the row tappable without the grey
            // chevron List would add.
            NavigationLink(value: item.id) { EmptyView() }
                .opacity(0)
            ItemRowView(item: item)
        }
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 5, leading: 18, bottom: 5, trailing: 18))
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                store.deleteItem(item)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func listHeader(title: String, tint: Color,
                            actionTitle: String? = nil,
                            action: (() -> Void)? = nil) -> some View {
        HStack {
            Text(title.uppercased())
                .font(.caption2).fontWeight(.bold)
                .tracking(0.8)
                .foregroundStyle(tint)
            Spacer()
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.caption).fontWeight(.semibold)
                    .foregroundStyle(AppTheme.danger)
                    // Borderless, so only the text is tappable, not the row.
                    .buttonStyle(.borderless)
            }
        }
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 10, leading: 24, bottom: 2, trailing: 24))
    }

    // MARK: Sort and filter

    private var sortMenu: some View {
        Menu {
            Picker("Sort by", selection: $sort) {
                ForEach(VaultSort.allCases) { option in
                    Text(option.rawValue).tag(option)
                }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 38, height: 38)
                .glass(cornerRadius: 19, shadowRadius: 6, shadowOpacity: 0.08)
        }
        .accessibilityLabel("Sort items")
        .accessibilityValue(sort.rawValue)
    }

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Button {
                    withAnimation(.easeOut(duration: 0.15)) { categoryFilter = nil }
                } label: {
                    FilterChip(title: "All", isSelected: categoryFilter == nil)
                }
                .buttonStyle(.plain)

                ForEach(availableCategories) { category in
                    Button {
                        withAnimation(.easeOut(duration: 0.15)) {
                            categoryFilter = (categoryFilter == category) ? nil : category
                        }
                    } label: {
                        FilterChip(title: "\(category.emoji) \(category.rawValue)",
                                   isSelected: categoryFilter == category)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 4)
        }
    }

    // MARK: Empty

    private var emptyState: some View {
        let isFiltering = !searchText.isEmpty || categoryFilter != nil

        return GlassEmptyState(
            emoji: isFiltering ? "🔍" : (selectedSegment == .food ? "🧺" : "🧾"),
            title: isFiltering
                ? "No matches"
                : (selectedSegment == .food ? "Your pantry is empty" : "No purchases yet"),
            message: isFiltering
                ? "Try a different search or category."
                : (selectedSegment == .food
                   ? "Scan your first grocery item to start tracking expiry dates."
                   : "Scan a receipt to start tracking return windows and warranties."),
            actionTitle: isFiltering ? "Clear filters" : "Add an Item",
            action: {
                if isFiltering {
                    searchText = ""
                    categoryFilter = nil
                } else {
                    isShowingAddItem = true
                }
            }
        )
        .padding(.horizontal, 18)
    }
}
