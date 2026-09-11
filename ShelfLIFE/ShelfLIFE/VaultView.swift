//
//  AuthService.swift
//  ShelfLIFE
//
//  Created by Mac-LAB on 9/7/26.
//

import SwiftUI

// MARK: - Vault
/// The full list, split into Pantry and Purchases, with a search box.
struct VaultView: View {
    @EnvironmentObject var data: AppData

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {

                // Pantry / Purchases switch
                Picker("Type", selection: $data.selectedKind) {
                    Text("Pantry (\(data.foodItems.count))").tag(ItemKind.food)
                    Text("Purchases (\(data.purchaseItems.count))").tag(ItemKind.purchase)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 20)

                if data.vaultItems.isEmpty {
                    Spacer()
                    EmptyMessage(
                        emoji: data.searchText.isEmpty ? "📦" : "🔍",
                        title: data.searchText.isEmpty ? "Nothing here yet" : "No matches",
                        message: data.searchText.isEmpty
                            ? "Scan or add an item to start tracking it."
                            : "Try a different search."
                    )
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 10) {
                            ForEach(data.vaultItems) { item in
                                NavigationLink {
                                    ItemDetailView(item: item)
                                } label: {
                                    ItemRow(item: item)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                    }
                }
            }
            .padding(.top, 8)
            .background(AppColor.background)
            .navigationTitle("Vault")
            .searchable(text: $data.searchText, prompt: "Search")
        }
    }
}

#Preview {
    VaultView().environmentObject(AppData())
}
