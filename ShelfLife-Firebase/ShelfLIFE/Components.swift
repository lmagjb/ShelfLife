import SwiftUI

// Buttons and the glass surface itself live in GlassKit.swift.
// This file holds the pieces built on top of them.

// MARK: - Search bar

struct SearchBarView: View {
    @Binding var text: String
    var placeholder: String = "Search..."

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)

            TextField(placeholder, text: $text)
                .font(.subheadline)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .glass(cornerRadius: 16, shadowRadius: 8, shadowOpacity: 0.06)
    }
}

// MARK: - Expiry badge

struct ExpiryBadge: View {
    let item: PantryItem

    var body: some View {
        Text(item.expiryLabel)
            .font(.caption2).fontWeight(.bold)
            .foregroundStyle(item.urgencyColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background {
                Capsule().fill(item.urgencyColor.opacity(0.18))
                Capsule().strokeBorder(item.urgencyColor.opacity(0.35), lineWidth: 1)
            }
    }
}

// MARK: - Item avatar
/// The emoji sits in a tinted glass disc, so the row keeps the frosted
/// language instead of dropping a flat grey square into it.

struct ItemAvatar: View {
    let item: PantryItem
    var size: CGFloat = 46

    var body: some View {
        Text(item.emoji)
            .font(.system(size: size * 0.46))
            .frame(width: size, height: size)
            .background {
                Circle().fill(item.urgencyColor.opacity(0.18))
                Circle().fill(
                    LinearGradient(colors: [Color.white.opacity(0.35), Color.white.opacity(0)],
                                   startPoint: .top, endPoint: .bottom)
                )
            }
            .overlay {
                Circle().strokeBorder(Color.white.opacity(0.35), lineWidth: 1)
            }
    }
}

// MARK: - Item row

struct ItemRowView: View {
    let item: PantryItem

    var body: some View {
        HStack(spacing: 13) {
            ItemAvatar(item: item)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.quantity.map { "\(item.name) ×\($0)" } ?? item.name)
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text("\(item.category.rawValue) · \(item.source)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            ExpiryBadge(item: item)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .glass(cornerRadius: 20, shadowRadius: 10, shadowOpacity: 0.07)
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        // VoiceOver reads the row as one sentence instead of four pieces.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(item.name), \(item.category.rawValue), \(item.expiryLabel)")
    }
}

// MARK: - Section header

struct SectionHeaderView: View {
    let title: String
    var action: (() -> Void)? = nil
    var actionLabel: String = "View All"

    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)

            Spacer()

            if let action {
                Button(action: action) {
                    HStack(spacing: 3) {
                        Text(actionLabel)
                        Image(systemName: "chevron.right").font(.caption2)
                    }
                    .font(.caption).fontWeight(.semibold)
                    .foregroundStyle(AppTheme.sage)
                }
            }
        }
    }
}

// MARK: - Category chip

struct CategoryChipView: View {
    let category: ItemCategory
    let isSelected: Bool

    var body: some View {
        FilterChip(title: category.rawValue, isSelected: isSelected)
    }
}

// MARK: - Filter chip
/// Pill used for categories, the Vault filter and quick date buttons.

struct FilterChip: View {
    let title: String
    let isSelected: Bool

    var body: some View {
        Text(title)
            .font(.subheadline).fontWeight(.medium)
            .foregroundStyle(isSelected ? .white : .primary)
            .padding(.horizontal, 15)
            .padding(.vertical, 9)
            .background {
                if isSelected {
                    Capsule().fill(
                        LinearGradient(colors: [AppTheme.sage, AppTheme.sage.opacity(0.78)],
                                       startPoint: .top, endPoint: .bottom)
                    )
                    Capsule().strokeBorder(Color.white.opacity(0.3), lineWidth: 1)
                } else {
                    Capsule().fill(.ultraThinMaterial)
                    Capsule().strokeBorder(Color.white.opacity(0.28), lineWidth: 1)
                }
            }
            .shadow(color: isSelected ? AppTheme.sage.opacity(0.3) : Color.black.opacity(0.05),
                    radius: isSelected ? 8 : 4, y: isSelected ? 4 : 2)
            .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Undo bar
/// Shown for a few seconds after a delete, so a mistaken swipe can be
/// taken back.

struct UndoToast: View {
    let message: String
    let onUndo: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "trash")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.danger)

            Text(message)
                .font(.subheadline).fontWeight(.medium)
                .lineLimit(1)

            Spacer(minLength: 8)

            Button("Undo", action: onUndo)
                .font(.subheadline).fontWeight(.bold)
                .foregroundStyle(AppTheme.sage)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .glass(cornerRadius: 22, material: .regularMaterial, shadowRadius: 14, shadowOpacity: 0.16)
        .padding(.horizontal, 18)
    }
}

// MARK: - Segmented control
/// A frosted replacement for `.pickerStyle(.segmented)`, which paints an
/// opaque track that fights the glass surfaces around it.

struct GlassSegmentedControl<T: Hashable>: View {
    @Binding var selection: T
    let options: [(value: T, label: String)]
    @Namespace private var namespace

    var body: some View {
        HStack(spacing: 4) {
            ForEach(options.indices, id: \.self) { index in
                let option = options[index]
                Button {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                        selection = option.value
                    }
                } label: {
                    Text(option.label)
                        .font(.subheadline).fontWeight(.semibold)
                        .foregroundStyle(selection == option.value ? .white : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background {
                            if selection == option.value {
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [AppTheme.sage, AppTheme.sage.opacity(0.8)],
                                            startPoint: .top, endPoint: .bottom)
                                    )
                                    .matchedGeometryEffect(id: "segment", in: namespace)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .glass(cornerRadius: 26, shadowRadius: 8, shadowOpacity: 0.06)
    }
}

// MARK: - Settings-style row

struct GlassRow: View {
    var icon: String
    var tint: Color = AppTheme.sage
    var title: String
    var value: String = ""
    var showsChevron: Bool = true

    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)
                .background(Circle().fill(tint.opacity(0.16)))

            Text(title)
                .font(.subheadline)
                .foregroundStyle(.primary)

            Spacer(minLength: 8)

            if !value.isEmpty {
                Text(value)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.caption2).fontWeight(.semibold)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .contentShape(Rectangle())
    }
}

// MARK: - Empty state

struct GlassEmptyState: View {
    let emoji: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 14) {
            Text(emoji)
                .font(.system(size: 44))
                .frame(width: 92, height: 92)
                .background {
                    Circle().fill(.ultraThinMaterial)
                    Circle().strokeBorder(Color.white.opacity(0.35), lineWidth: 1)
                }

            VStack(spacing: 6) {
                Text(title).font(.headline)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(PrimaryButtonStyle())
                    .fixedSize()
                    .padding(.top, 4)
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity)
    }
}
