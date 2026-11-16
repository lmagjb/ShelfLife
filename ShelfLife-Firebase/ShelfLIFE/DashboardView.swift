import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var store: ShelfLifeStore
    @State private var isShowingNotifications = false

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    moneyAtRiskCard
                    quickStats

                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeaderView(title: "Expiring Soon")

                        if store.expiringSoon.isEmpty {
                            GlassEmptyState(
                                emoji: "🌿",
                                title: "Nothing urgent",
                                message: "Everything you're tracking still has room to breathe."
                            )
                        } else {
                            ForEach(store.expiringSoon) { item in
                                NavigationLink(value: item.id) {
                                    ItemRowView(item: item)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    if !store.expiredItems.isEmpty {
                        expiredSection
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 4)
                .padding(.bottom, 110)
            }
            .navigationTitle("ShelfLife")
            .transparentChrome()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isShowingNotifications = true
                    } label: {
                        Image(systemName: store.notifications.isEmpty ? "bell" : "bell.badge")
                    }
                    .buttonStyle(GlassIconButtonStyle())
                    .accessibilityLabel("Notifications")
                    .accessibilityValue(store.notifications.isEmpty
                                        ? "None" : "\(store.notifications.count) alerts")
                }
            }
            // `PantryItem.id` is a String (it doubles as the Firestore
            // document ID), so the destination has to match that type.
            .navigationDestination(for: String.self) { id in
                if let item = store.items.first(where: { $0.id == id }) {
                    ItemDetailView(item: item)
                }
            }
            .sheet(isPresented: $isShowingNotifications) {
                NotificationsView()
            }
        }
    }

    // MARK: Hero

    private var moneyAtRiskCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("MONEY AT RISK THIS WEEK")
                    .font(.caption2).fontWeight(.bold)
                    .tracking(0.9)
                    .foregroundStyle(.secondary)

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 9))
                    Text("Warning")
                }
                .font(.caption2).fontWeight(.bold)
                .foregroundStyle(AppTheme.warning)
                .padding(.horizontal, 9).padding(.vertical, 5)
                .background {
                    Capsule().fill(AppTheme.warning.opacity(0.2))
                    Capsule().strokeBorder(AppTheme.warning.opacity(0.4), lineWidth: 1)
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("₱\(Int(store.totalAtRisk))")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(colors: [.primary, .primary.opacity(0.65)],
                                       startPoint: .top, endPoint: .bottom)
                    )

                Text("across \(atRiskCount) items")
                    .font(.caption).foregroundStyle(.secondary)
            }

            GlassDivider(inset: 0)

            VStack(alignment: .leading, spacing: 10) {
                riskRow(icon: "leaf.fill", tint: AppTheme.sage,
                        text: countText(spoilingCount, "food item", "spoiling soon"))
                riskRow(icon: "doc.text.fill", tint: AppTheme.amber,
                        text: countText(returnCount, "return window", "closing this week"))
                riskRow(icon: "shield.fill", tint: AppTheme.violet,
                        text: countText(warrantyCount, "warranty", "ending this month"))
            }
        }
        .glassCard(tint: AppTheme.warning, padding: 20)
    }

    private func riskRow(icon: String, tint: Color, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 24, height: 24)
                .background(Circle().fill(tint.opacity(0.18)))

            Text(text).font(.subheadline)
            Spacer()
        }
    }

    // MARK: Quick stats

    private var quickStats: some View {
        HStack(spacing: 12) {
            statTile(value: "\(store.pantryItems.count)", label: "In pantry",
                     icon: "basket.fill", tint: AppTheme.sage)
            statTile(value: "\(store.purchaseItems.count)", label: "Purchases",
                     icon: "bag.fill", tint: AppTheme.teal)
        }
    }

    private func statTile(value: String, label: String, icon: String, tint: Color) -> some View {
        HStack(spacing: 11) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 34, height: 34)
                .background(Circle().fill(tint.opacity(0.18)))

            VStack(alignment: .leading, spacing: 1) {
                Text(value).font(.title3).fontWeight(.bold)
                Text(label).font(.caption2).foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .glass(cornerRadius: 20, tint: tint, tintOpacity: 0.10,
               shadowRadius: 10, shadowOpacity: 0.07)
    }

    // MARK: Derived

    private var atRiskCount: Int {
        store.atRiskItems.count
    }

    private var spoilingCount: Int {
        store.pantryItems.filter { (0...3).contains($0.daysLeft) }.count
    }

    private var returnCount: Int {
        store.purchaseItems.filter { (0...7).contains($0.daysLeft) }.count
    }

    private var warrantyCount: Int {
        store.purchaseItems.filter { item in
            guard let left = item.warrantyDaysLeft else { return false }
            return (0...30).contains(left)
        }.count
    }

    /// "1 food item spoiling soon" / "3 food items spoiling soon".
    private func countText(_ count: Int, _ noun: String, _ rest: String) -> String {
        let plural = noun == "warranty" ? "warranties" : noun + "s"
        return "\(count) \(count == 1 ? noun : plural) \(rest)"
    }

    // MARK: Expired

    private var expiredSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Expired").font(.headline)
                Spacer()
                if store.totalWasted > 0 {
                    Text("₱\(Int(store.totalWasted)) wasted")
                        .font(.caption).fontWeight(.semibold)
                        .foregroundStyle(AppTheme.danger)
                }
            }

            ForEach(store.expiredItems) { item in
                NavigationLink(value: item.id) {
                    ItemRowView(item: item)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
