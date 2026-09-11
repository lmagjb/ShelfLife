//
//  AuthService.swift
//  ShelfLIFE
//
//  Created by Mac-LAB on 9/7/26.
//


import SwiftUI

// MARK: - Item detail
/// Food shows recipes that use it up. A purchase shows its store details.
struct ItemDetailView: View {
    @EnvironmentObject var data: AppData
    @Environment(\.dismiss) var dismiss
    let item: ShelfItem

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {

                // Colored header
                VStack(spacing: 8) {
                    Text(item.emoji).font(.system(size: 50))
                    Text(item.name)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                    Text(item.deadlineText)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.9))
                }
                .frame(maxWidth: .infinity)
                .padding(28)
                .background(item.isDone ? AppColor.gray : item.color)
                .cornerRadius(24)

                // Facts
                VStack(spacing: 12) {
                    DetailLine(name: "Category", value: item.category)
                    Divider()
                    DetailLine(name: item.kind == .food ? "Source" : "Store",
                               value: item.store)
                    Divider()
                    DetailLine(name: item.kind == .food ? "Expires" : "Deadline",
                               value: item.dateText)
                    Divider()
                    DetailLine(name: "Price", value: item.priceText)
                }
                .padding(16)
                .cardStyle()

                // Recipes for food
                if item.kind == .food && !item.isDone {
                    Heading(text: "Use It Up")
                    ForEach(SampleData.recipes(for: item)) { recipe in
                        NavigationLink {
                            RecipeView(recipe: recipe, item: item)
                        } label: {
                            HStack(spacing: 12) {
                                Text(recipe.emoji).font(.system(size: 24))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(recipe.name)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(AppColor.text)
                                    Text("\(recipe.minutes) minutes")
                                        .font(.system(size: 12))
                                        .foregroundColor(AppColor.gray)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(AppColor.gray)
                            }
                            .padding(14)
                            .cardStyle()
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Buttons
                if item.isDone {
                    OutlineButton(title: "Undo") {
                        data.undo(item)
                        dismiss()
                    }
                } else {
                    FilledButton(
                        title: item.kind == .food ? "Mark as Used" : "Mark as Handled",
                        color: AppColor.green
                    ) {
                        data.markDone(item)
                        dismiss()
                    }
                }
            }
            .padding(20)
        }
        .background(AppColor.background)
        .navigationTitle("Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .destructive) {
                    data.delete(item)
                    dismiss()
                } label: {
                    Image(systemName: "trash")
                }
            }
        }
    }
}

// MARK: - Recipe
struct RecipeView: View {
    @EnvironmentObject var data: AppData
    @Environment(\.dismiss) var dismiss
    let recipe: Recipe
    let item: ShelfItem

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                ZStack {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(AppColor.green.opacity(0.25))
                        .frame(height: 150)
                    Text(recipe.emoji).font(.system(size: 60))
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(recipe.name)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(AppColor.text)
                    Text("\(recipe.minutes) minutes · uses your \(item.name)")
                        .font(.system(size: 13))
                        .foregroundColor(AppColor.gray)
                }

                Heading(text: "Ingredients")
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(recipe.ingredients, id: \.self) { line in
                        HStack(alignment: .top, spacing: 8) {
                            Text("•").foregroundColor(AppColor.green)
                            Text(line)
                                .font(.system(size: 14))
                                .foregroundColor(AppColor.text)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .cardStyle()

                Heading(text: "Steps")
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(Array(recipe.steps.enumerated()), id: \.offset) { number, step in
                        HStack(alignment: .top, spacing: 12) {
                            Text("\(number + 1)")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 22, height: 22)
                                .background(AppColor.green)
                                .clipShape(Circle())
                            Text(step)
                                .font(.system(size: 14))
                                .foregroundColor(AppColor.text)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .cardStyle()

                FilledButton(title: "Mark \(item.name) as Used",
                             color: AppColor.green) {
                    data.markDone(item)
                    dismiss()
                }
            }
            .padding(20)
        }
        .background(AppColor.background)
        .navigationTitle("Recipe")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        ItemDetailView(item: SampleData.items[0])
            .environmentObject(AppData())
    }
}
