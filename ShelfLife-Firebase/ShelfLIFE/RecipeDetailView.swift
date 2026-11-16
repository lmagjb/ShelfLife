import SwiftUI

struct RecipeDetailView: View {
    @EnvironmentObject var store: ShelfLifeStore
    @Environment(\.dismiss) private var dismiss
    let item: PantryItem
    let recipe: RescueRecipe

    @State private var checked: Set<Int> = []

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                hero

                VStack(alignment: .leading, spacing: 12) {
                    Text(recipe.name)
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                    HStack(spacing: 8) {
                        statChip("clock", "\(recipe.prepMinutes) min")
                        statChip("person.2", "\(recipe.servings) servings")
                        statChip("flame", "\(recipe.calories) cal")
                    }
                }

                usesCard
                ingredientsCard
                stepsCard
            }
            .padding(.horizontal, 18)
            .padding(.top, 6)
            .padding(.bottom, 24)
        }
        .navigationTitle("Recipe")
        .navigationBarTitleDisplayMode(.inline)
        .transparentChrome()
        .safeAreaInset(edge: .bottom) {
            Button("Mark \(item.name) as Used") {
                store.markUsed(item)
                dismiss()
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background {
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

    // MARK: Pieces

    private var hero: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(colors: [AppTheme.amber.opacity(0.35), AppTheme.sage.opacity(0.3)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                )
            Text(recipe.emoji)
                .font(.system(size: 72))
                .shadow(color: Color.black.opacity(0.15), radius: 12, y: 8)
        }
        .frame(height: 180)
        .glass(cornerRadius: 28)
    }

    private func statChip(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.caption2)
            Text(text).font(.caption).fontWeight(.medium)
        }
        .padding(.horizontal, 11).padding(.vertical, 7)
        .glassChip(cornerRadius: 14)
    }

    /// Ties the recipe back to the pantry item it rescues.
    private var usesCard: some View {
        HStack(spacing: 12) {
            ItemAvatar(item: item, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text("YOU'LL USE")
                    .font(.caption2).fontWeight(.bold)
                    .tracking(0.6)
                    .foregroundStyle(.secondary)
                Text(item.name).font(.subheadline).fontWeight(.semibold)
            }
            Spacer(minLength: 0)
            ExpiryBadge(item: item)
        }
        .glassCard(cornerRadius: 22, tint: item.urgencyColor, padding: 14)
    }

    private var ingredientsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Ingredients").font(.headline)
                Spacer()
                Text("\(checked.count)/\(recipe.ingredients.count)")
                    .font(.caption).fontWeight(.semibold)
                    .foregroundStyle(.secondary)
            }

            ForEach(Array(recipe.ingredients.enumerated()), id: \.offset) { index, ingredient in
                Button {
                    if checked.contains(index) { checked.remove(index) } else { checked.insert(index) }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: checked.contains(index) ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(checked.contains(index) ? AppTheme.sage : Color.secondary)
                        Text(ingredient)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                            .strikethrough(checked.contains(index))
                            .opacity(checked.contains(index) ? 0.55 : 1)
                        Spacer(minLength: 0)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .glassCard(padding: 18)
    }

    private var stepsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Steps").font(.headline)

            ForEach(Array(recipe.steps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .top, spacing: 12) {
                    Text("\(index + 1)")
                        .font(.caption).fontWeight(.bold)
                        .foregroundStyle(.white)
                        .frame(width: 24, height: 24)
                        .background(
                            Circle().fill(
                                LinearGradient(colors: [AppTheme.mint, AppTheme.sage],
                                               startPoint: .top, endPoint: .bottom)
                            )
                        )
                    Text(step)
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
            }
        }
        .glassCard(padding: 18)
    }
}
