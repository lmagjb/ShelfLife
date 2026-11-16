import SwiftUI
import Foundation

struct ItemDetailView: View {
    @EnvironmentObject var store: ShelfLifeStore
    @Environment(\.dismiss) private var dismiss
    /// The item as it was when the screen opened.
    private let opened: PantryItem

    init(item: PantryItem) {
        self.opened = item
    }

    /// Always the latest saved version, so changes made in Edit show up
    /// straight away. Falls back to the opened copy once it's deleted.
    private var item: PantryItem {
        store.items.first(where: { $0.id == opened.id }) ?? opened
    }

    @State private var isShowingMarkUsed = false
    @State private var isShowingReturn = false
    @State private var isShowingEdit = false
    @State private var isShowingDeleteConfirm = false
    @State private var isShowingExtend = false
    @State private var isShowingUseSome = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                header

                if item.type == .purchase {
                    purchaseDetails
                    milestoneTimeline
                } else {
                    foodDetails
                    rescueRecipes
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 6)
            .padding(.bottom, 24)
        }
        .navigationTitle(item.type == .purchase ? "Purchase" : "Item")
        .navigationBarTitleDisplayMode(.inline)
        .transparentChrome()
        .safeAreaInset(edge: .bottom) { actionButtons }
        .sheet(isPresented: $isShowingMarkUsed) {
            MarkUsedConfirmationView(item: item) { dismiss() }
        }
        .sheet(isPresented: $isShowingReturn) {
            ReturnConfirmationView(item: item) { dismiss() }
        }
        .sheet(isPresented: $isShowingEdit) {
            AddEditItemView(editing: item)
        }
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button { isShowingEdit = true } label: {
                    Image(systemName: "pencil")
                }
                .buttonStyle(GlassIconButtonStyle(size: 34))
                .accessibilityLabel("Edit item")

                Button { isShowingDeleteConfirm = true } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(AppTheme.danger)
                }
                .buttonStyle(GlassIconButtonStyle(size: 34))
                .accessibilityLabel("Delete item")
            }
        }
        .confirmationDialog("Delete \(item.name)?",
                            isPresented: $isShowingDeleteConfirm,
                            titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                store.deleteItem(item)
                dismiss()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This removes it from ShelfLife on all your devices.")
        }
        .confirmationDialog("You have \(item.count) left",
                            isPresented: $isShowingUseSome,
                            titleVisibility: .visible) {
            Button("Used 1") { store.useOne(item) }
            Button("Used all \(item.count)") { isShowingMarkUsed = true }
            Button("Cancel", role: .cancel) { }
        }
        .confirmationDialog("Extend the expiry date",
                            isPresented: $isShowingExtend,
                            titleVisibility: .visible) {
            Button("+1 day")  { store.extend(item, byDays: 1) }
            Button("+3 days") { store.extend(item, byDays: 3) }
            Button("+1 week") { store.extend(item, byDays: 7) }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text(item.isExpired
                 ? "It has already expired, so the new date counts from today."
                 : "Currently \(item.expiryDate.formatted(date: .abbreviated, time: .omitted)).")
        }
    }

    /// Text for the pill under the item name.
    private var statusText: String {
        guard item.type == .purchase else { return item.expiryLabel }
        if item.isUnderWarrantyOnly {
            let left = item.warrantyDaysLeft ?? 0
            return left == 0 ? "Warranty ends today" : "Under warranty · \(left) days left"
        }
        if item.daysLeft < 0 { return "Return window closed" }
        if item.isReturning {
            if item.daysLeft == 0 { return "Return started · drop off today" }
            return "Return started · drop off within \(item.daysLeft) days"
        }
        if item.daysLeft == 0 { return "Return window closes today" }
        if item.daysLeft == 1 { return "Return window closes tomorrow" }
        return "Return window closes in \(item.daysLeft) days"
    }

    // MARK: Header

    private var header: some View {
        VStack(spacing: 13) {
            Text(item.emoji)
                .font(.system(size: 44))
                .frame(width: 88, height: 88)
                .background {
                    Circle().fill(item.urgencyColor.opacity(0.16))
                    Circle().fill(.ultraThinMaterial).opacity(0.5)
                    Circle().fill(
                        LinearGradient(colors: [Color.white.opacity(0.4), Color.white.opacity(0)],
                                       startPoint: .top, endPoint: .center)
                    )
                }
                .overlay {
                    Circle().strokeBorder(Color.white.opacity(0.4), lineWidth: 1)
                }
                .shadow(color: item.urgencyColor.opacity(0.28), radius: 18, y: 9)

            Text(item.name)
                .font(.title3).fontWeight(.semibold)
                .multilineTextAlignment(.center)

            Text(statusText)
                .font(.caption).fontWeight(.semibold)
                .foregroundStyle(item.urgencyColor)
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background {
                    Capsule().fill(item.urgencyColor.opacity(0.18))
                    Capsule().strokeBorder(item.urgencyColor.opacity(0.35), lineWidth: 1)
                }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .glass(cornerRadius: 28, tint: item.urgencyColor, tintOpacity: 0.10)
    }

    // MARK: Detail blocks

    private var foodDetails: some View {
        VStack(spacing: 0) {
            detailRow("Category", item.category.rawValue)
            GlassDivider()
            detailRow("Purchased", "\(abs(Calendar.current.dateComponents([.day], from: item.purchasedDate, to: Date()).day ?? 0)) days ago")
            GlassDivider()
            detailRow("Source", item.source)
            if let quantity = item.quantity {
                GlassDivider()
                detailRow("Quantity", "\(quantity) left")
            }
            if let amount = item.amount {
                GlassDivider()
                detailRow("Price", Money.format(amount))
            }
            if !item.notes.isEmpty {
                GlassDivider()
                detailRow("Notes", item.notes)
            }
        }
        .glass(cornerRadius: AppTheme.cardRadius)
    }

    private var purchaseDetails: some View {
        VStack(spacing: 0) {
            detailRow("Store", item.source)
            GlassDivider()
            detailRow("Amount", item.amount.map { Money.format($0) } ?? "Not set")
            GlassDivider()
            detailRow("Purchased", item.purchasedDate.formatted(date: .abbreviated, time: .omitted))
            GlassDivider()
            detailRow("Return deadline", item.expiryDate.formatted(date: .abbreviated, time: .omitted))
            GlassDivider()
            detailRow("Warranty until", item.warrantyDate?.formatted(date: .abbreviated, time: .omitted) ?? "None")
            if !item.notes.isEmpty {
                GlassDivider()
                detailRow("Notes", item.notes)
            }
        }
        .glass(cornerRadius: AppTheme.cardRadius)
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(value).fontWeight(.semibold)
                .multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }

    // MARK: Timeline

    private var milestoneTimeline: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Milestone Timeline")
                .font(.headline)
                .padding(.bottom, 16)

            milestoneRow("Purchased item",
                         item.purchasedDate.formatted(date: .long, time: .omitted),
                         done: true, isLast: false)
            milestoneRow(item.notify ? "Return reminder" : "Return reminder (off)",
                         reminderDate.formatted(date: .long, time: .omitted),
                         done: reminderDate < Date(), isLast: false)
            if let started = item.returnStartedDate {
                milestoneRow("Return started",
                             started.formatted(date: .long, time: .omitted),
                             done: true, isLast: false)
            }
            milestoneRow("Return window closes",
                         item.expiryDate.formatted(date: .long, time: .omitted),
                         done: item.daysLeft < 0, isLast: item.warrantyDate == nil)
            if let warranty = item.warrantyDate {
                milestoneRow("Warranty ends",
                             warranty.formatted(date: .long, time: .omitted),
                             done: (item.warrantyDaysLeft ?? 0) < 0, isLast: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(padding: 20)
    }

    /// When the return reminder goes off, using the Settings choice.
    private var reminderDate: Date {
        let days = UserDefaults.standard.object(forKey: ReminderSettings.daysBeforeKey) as? Int
            ?? ReminderSettings.defaultDaysBefore
        return Calendar.current.date(byAdding: .day, value: -days, to: item.expiryDate) ?? item.expiryDate
    }

    private func milestoneRow(_ title: String, _ date: String,
                              done: Bool, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 13) {
            VStack(spacing: 0) {
                Circle()
                    .fill(done ? AppTheme.sage : Color.primary.opacity(0.18))
                    .frame(width: 11, height: 11)
                    .overlay {
                        Circle().strokeBorder(Color.white.opacity(0.5), lineWidth: 1)
                    }
                    .padding(.top, 4)

                if !isLast {
                    Rectangle()
                        .fill(Color.primary.opacity(0.12))
                        .frame(width: 1.5)
                        .frame(minHeight: 30)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline).fontWeight(.semibold)
                Text(date).font(.caption).foregroundStyle(.secondary)
            }
            .padding(.bottom, isLast ? 0 : 16)

            Spacer(minLength: 0)
        }
    }

    // MARK: Recipes

    private var rescueRecipes: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Rescue Recipes").font(.headline)
                Text("Use it up before it turns")
                    .font(.caption).foregroundStyle(.secondary)
            }

            ForEach(store.recipes(for: item)) { recipe in
                NavigationLink {
                    RecipeDetailView(item: item, recipe: recipe)
                } label: {
                    HStack(spacing: 13) {
                        Text(recipe.emoji)
                            .font(.system(size: 22))
                            .frame(width: 46, height: 46)
                            .background {
                                Circle().fill(AppTheme.sage.opacity(0.16))
                                Circle().strokeBorder(Color.white.opacity(0.3), lineWidth: 1)
                            }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(recipe.name)
                                .font(.subheadline).fontWeight(.semibold)
                                .foregroundStyle(.primary)
                            Text("\(recipe.prepMinutes) min · \(recipe.servings) servings")
                                .font(.caption).foregroundStyle(.secondary)
                        }

                        Spacer(minLength: 0)

                        Image(systemName: "chevron.right")
                            .font(.caption2).fontWeight(.semibold)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .glass(cornerRadius: 20, shadowRadius: 10, shadowOpacity: 0.07)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Actions

    private var actionButtons: some View {
        HStack(spacing: 11) {
            if item.type == .purchase {
                if item.daysLeft < 0 {
                    // Too late to return it; the only thing left is removing it.
                    Button("Remove from ShelfLife") { isShowingDeleteConfirm = true }
                        .buttonStyle(SecondaryButtonStyle())
                } else if item.isReturning {
                    Button("Cancel Return") { store.cancelReturn(item) }
                        .buttonStyle(SecondaryButtonStyle())
                    Button("Mark Returned") {
                        store.completeReturn(item)
                        dismiss()
                    }
                    .buttonStyle(PrimaryButtonStyle())
                } else {
                    Button("Keep It") { dismiss() }
                        .buttonStyle(SecondaryButtonStyle())
                    Button("Start Return") { isShowingReturn = true }
                        .buttonStyle(PrimaryButtonStyle())
                }
            } else {
                Button("Mark Used") {
                    if item.count > 1 { isShowingUseSome = true } else { isShowingMarkUsed = true }
                }
                .buttonStyle(SecondaryButtonStyle())
                Button("Extend") { isShowingExtend = true }
                    .buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .background {
            // Soft fade so content scrolling underneath dissolves out
            // instead of cutting hard against the buttons.
            Rectangle()
                .fill(.ultraThinMaterial)
                .mask {
                LinearGradient(colors: [Color.clear, Color.black, Color.black],
                               startPoint: .top, endPoint: .bottom)
            }
            .ignoresSafeArea()
        }
    }
}
