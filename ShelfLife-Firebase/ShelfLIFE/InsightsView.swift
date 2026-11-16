import SwiftUI

struct InsightsView: View {
    @EnvironmentObject var store: ShelfLifeStore

    /// Spending per category, worked out from what is actually tracked
    /// rather than a fixed table, so the chart can never disagree with
    /// the Vault.
    private var categorySpending: [(name: String, total: Double)] {
        let priced = store.items.filter { ($0.amount ?? 0) > 0 }
        let grouped = Dictionary(grouping: priced) { $0.category.rawValue }
        return grouped
            .map { (name: $0.key, total: $0.value.reduce(0) { $0 + ($1.amount ?? 0) }) }
            .sorted { $0.total > $1.total }
    }

    private var largestSpend: Double {
        max(categorySpending.first?.total ?? 1, 1)
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    headlineTiles
                    historyCard
                    monthlyCard
                    spendingCard
                    habitsCard
                    recentHistory
                }
                .padding(.horizontal, 18)
                .padding(.top, 4)
                .padding(.bottom, 110)
            }
            .navigationTitle("Insights")
            .transparentChrome()
        }
    }

    // MARK: Headline numbers

    private var headlineTiles: some View {
        HStack(spacing: 12) {
            statBox(value: Money.format(store.totalAtRisk),
                    label: "At risk this week",
                    icon: "exclamationmark.triangle.fill",
                    tint: AppTheme.warning)

            statBox(value: "\(store.items.count)",
                    label: "Items tracked",
                    icon: "square.stack.3d.up.fill",
                    tint: AppTheme.teal)
        }
    }

    private func statBox(value: String, label: String, icon: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 32, height: 32)
                .background(Circle().fill(tint.opacity(0.18)))

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .lineLimit(1).minimumScaleFactor(0.7)
                Text(label)
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: 22, tint: tint, padding: 16)
    }

    // MARK: Spending chart
    /// One measure, so one hue — length carries the comparison. Labels
    /// and values stay in text ink; the bar alone is coloured.

    private var spendingCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Spending by Category").font(.headline)
                Text("Across everything with a recorded price")
                    .font(.caption).foregroundStyle(.secondary)
            }

            if categorySpending.isEmpty {
                Text("Add a purchase with an amount and the breakdown appears here.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 14) {
                    ForEach(categorySpending, id: \.name) { entry in
                        spendingBar(name: entry.name, total: entry.total)
                    }
                }
            }
        }
        .glassCard(padding: 20)
    }

    private func spendingBar(name: String, total: Double) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(name)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                Spacer()
                Text(Money.format(total))
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundStyle(.secondary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Recessive track
                    Capsule()
                        .fill(Color.primary.opacity(0.07))

                    Capsule()
                        .fill(
                            LinearGradient(colors: [AppTheme.sage, AppTheme.mint],
                                           startPoint: .leading, endPoint: .trailing)
                        )
                        .frame(width: max(geo.size.width * CGFloat(total / largestSpend), 8))
                }
            }
            .frame(height: 9)
        }
    }

    // MARK: Used vs. wasted

    private var historyCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Used vs. Wasted").font(.headline)
                Text("Food you finished in time against expired food you cleared")
                    .font(.caption).foregroundStyle(.secondary)
            }

            if let rate = store.usedRate {
                HStack(spacing: 12) {
                    outcomeBox(value: Money.format(store.totalSaved),
                               label: "\(store.usedCount) used in time", tint: AppTheme.sage)
                    outcomeBox(value: Money.format(store.totalWastedHistory),
                               label: "\(store.wastedCount) wasted", tint: AppTheme.danger)
                }

                VStack(alignment: .leading, spacing: 7) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(AppTheme.danger.opacity(0.35))
                            Capsule()
                                .fill(LinearGradient(colors: [AppTheme.sage, AppTheme.mint],
                                                     startPoint: .leading, endPoint: .trailing))
                                .frame(width: max(geo.size.width * CGFloat(rate), 8))
                        }
                    }
                    .frame(height: 9)

                    Text("\(Int((rate * 100).rounded()))% of your food was used before it expired")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)

                if store.totalReturned > 0 {
                    Text("Plus \(Money.format(store.totalReturned)) back from purchases you returned in time.")
                        .font(.caption).fontWeight(.medium)
                        .foregroundStyle(AppTheme.teal)
                }
            } else {
                Text("Mark food as used, or clear expired items, and your record starts here.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(padding: 20)
    }

    private func outcomeBox(value: String, label: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(tint)
                .lineLimit(1).minimumScaleFactor(0.7)
            Text(label)
                .font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(tint.opacity(0.12)))
    }

    // MARK: Monthly trend
    /// Two bars per month: used (green) and wasted (red), sharing one scale.

    private var monthlyCard: some View {
        let months = store.monthlyHistory
        let peak = max(months.map { max($0.used, $0.wasted) }.max() ?? 0, 1)
        let hasData = months.contains { $0.used > 0 || $0.wasted > 0 }

        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text("Last 6 Months").font(.headline)
                Spacer()
                legendDot("Used", AppTheme.sage)
                legendDot("Wasted", AppTheme.danger)
            }

            if hasData {
                HStack(alignment: .bottom, spacing: 10) {
                    ForEach(months) { month in
                        VStack(spacing: 6) {
                            HStack(alignment: .bottom, spacing: 3) {
                                monthBar(month.used, peak: peak, tint: AppTheme.sage)
                                monthBar(month.wasted, peak: peak, tint: AppTheme.danger)
                            }
                            .frame(height: 96, alignment: .bottom)

                            Text(month.label)
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(month.label): \(Money.format(month.used)) used, \(Money.format(month.wasted)) wasted")
                    }
                }
            } else {
                Text("No priced items in your history yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(padding: 20)
    }

    private func monthBar(_ value: Double, peak: Double, tint: Color) -> some View {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(tint.opacity(value > 0 ? 1 : 0.15))
            .frame(width: 11, height: max(CGFloat(value / peak) * 96, 3))
    }

    private func legendDot(_ label: String, _ tint: Color) -> some View {
        HStack(spacing: 5) {
            Circle().fill(tint).frame(width: 7, height: 7)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
    }

    // MARK: Recent history

    @ViewBuilder
    private var recentHistory: some View {
        if !store.history.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Recent Activity").font(.headline)

                VStack(spacing: 0) {
                    let recent = Array(store.history.prefix(6))
                    ForEach(recent.indices, id: \.self) { index in
                        if index > 0 { GlassDivider() }
                        historyRow(recent[index])
                    }
                }
                .glass(cornerRadius: AppTheme.cardRadius)
            }
        }
    }

    private func historyRow(_ entry: HistoryEntry) -> some View {
        let tint: Color = entry.outcome == .wasted ? AppTheme.danger
            : (entry.outcome == .returned ? AppTheme.teal : AppTheme.sage)

        return HStack(spacing: 12) {
            Text(entry.emoji).font(.system(size: 20))

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.name)
                    .font(.subheadline).fontWeight(.semibold)
                    .lineLimit(1)
                Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption2).foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                Text(entry.outcome.rawValue)
                    .font(.caption).fontWeight(.bold)
                    .foregroundStyle(tint)
                if let amount = entry.amount {
                    Text(Money.format(amount))
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }

    // MARK: Habits

    private var habitsCard: some View {
        HStack(alignment: .top, spacing: 13) {
            Image(systemName: "sparkles")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.sage)
                .frame(width: 34, height: 34)
                .background(Circle().fill(AppTheme.sage.opacity(0.18)))

            VStack(alignment: .leading, spacing: 4) {
                Text("HABITS FORMING")
                    .font(.caption2).fontWeight(.bold)
                    .tracking(0.8)
                    .foregroundStyle(AppTheme.sage)

                Text(habitsMessage)
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .glassCard(tint: AppTheme.sage, padding: 18)
    }

    private var habitsMessage: String {
        let urgent = store.expiringSoon.count
        let expired = store.expiredItems.count
        if store.items.isEmpty {
            return "Start scanning and your patterns will show up here."
        }
        if expired > 0 && urgent == 0 {
            return "\(expired) \(expired == 1 ? "item has" : "items have") expired. Clear them from the Vault to keep your list accurate."
        }
        if urgent == 0 {
            return "Nothing is close to expiring — you're staying ahead of it."
        }
        return "\(urgent) \(urgent == 1 ? "item needs" : "items need") attention in the next few days."
    }
}
