//
//  AuthService.swift
//  ShelfLIFE
//
//  Created by Mac-LAB on 9/7/26.
//

import SwiftUI

// MARK: - Home
/// Shows how much money is about to be lost, then the most urgent items.
struct HomeView: View {
    @EnvironmentObject var data: AppData
    @State private var showScan = false
    @State private var showAdd = false
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    moneyCard
                    buttonRow

                    Heading(text: "Expiring Soon")

                    if data.expiringSoon.isEmpty {
                        EmptyMessage(
                            emoji: "🧺",
                            title: "All caught up",
                            message: "Nothing needs your attention right now."
                        )
                        .cardStyle()
                    } else {
                        ForEach(data.expiringSoon) { item in
                            NavigationLink {
                                ItemDetailView(item: item)
                            } label: {
                                ItemRow(item: item)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(20)
            }
            .background(AppColor.background)
            .navigationTitle("ShelfLife")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                    }
                }
            }
            .sheet(isPresented: $showScan) { ScanView() }
            .sheet(isPresented: $showAdd) { AddItemView() }
            .sheet(isPresented: $showSettings) { SettingsView() }
        }
    }

    // Dark box with the total at risk
    private var moneyCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("MONEY AT RISK THIS WEEK")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white.opacity(0.6))

            Text("₱" + String(format: "%.0f", data.moneyAtRisk))
                .font(.system(size: 34, weight: .bold))
                .foregroundColor(.white)

            Text("\(data.atRiskCount) items · \(data.riskSummary)")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(AppColor.dark)
        .cornerRadius(20)
    }

    // Scan and Add shortcuts
    private var buttonRow: some View {
        HStack(spacing: 12) {
            shortcut(emoji: "📷", title: "Scan") { showScan = true }
            shortcut(emoji: "✍️", title: "Add") { showAdd = true }
        }
    }

    private func shortcut(emoji: String, title: String,
                          action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Text(emoji).font(.system(size: 22))
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppColor.text)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .cardStyle()
        }
    }
}

#Preview {
    HomeView().environmentObject(AppData())
}
