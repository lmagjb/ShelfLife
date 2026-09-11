//
//  AuthService.swift
//  ShelfLIFE
//
//  Created by Mac-LAB on 9/7/26.
//


import SwiftUI

// MARK: - Insights
/// Totals and a simple bar chart, all worked out from the current items.
struct InsightsView: View {
    @EnvironmentObject var data: AppData

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {

                    HStack(spacing: 12) {
                        StatBox(value: "₱" + String(format: "%.0f", data.savedTotal),
                                label: "SAVED",
                                color: AppColor.green)
                        StatBox(value: "\(data.doneCount)",
                                label: "COMPLETED",
                                color: AppColor.brown)
                    }

                    HStack(spacing: 12) {
                        StatBox(value: "\(data.foodItems.count)", label: "IN PANTRY")
                        StatBox(value: "\(data.purchaseItems.count)", label: "PURCHASES")
                        StatBox(value: "\(data.atRiskCount)",
                                label: "AT RISK",
                                color: data.atRiskCount > 0 ? AppColor.red : AppColor.text)
                    }

                    Heading(text: "Spending by Category")

                    if data.spending.isEmpty {
                        EmptyMessage(emoji: "📊",
                                     title: "No spending yet",
                                     message: "Add a purchase to see the breakdown.")
                            .cardStyle()
                    } else {
                        VStack(spacing: 12) {
                            ForEach(data.spending, id: \.name) { row in
                                bar(name: row.name, total: row.total)
                            }
                        }
                        .padding(16)
                        .cardStyle()
                    }
                }
                .padding(20)
            }
            .background(AppColor.background)
            .navigationTitle("Insights")
        }
    }

    // One bar in the chart
    private func bar(name: String, total: Double) -> some View {
        let biggest = data.spending.first?.total ?? 1
        let width = biggest > 0 ? total / biggest : 0

        return HStack(spacing: 10) {
            Text(name)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppColor.gray)
                .frame(width: 80, alignment: .leading)

            GeometryReader { space in
                ZStack(alignment: .leading) {
                    Capsule().fill(AppColor.soft)
                    Capsule()
                        .fill(AppColor.brown)
                        .frame(width: space.size.width * width)
                }
            }
            .frame(height: 10)

            Text("₱" + String(format: "%.0f", total))
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppColor.text)
                .frame(width: 60, alignment: .trailing)
        }
    }
}

#Preview {
    InsightsView().environmentObject(AppData())
}
