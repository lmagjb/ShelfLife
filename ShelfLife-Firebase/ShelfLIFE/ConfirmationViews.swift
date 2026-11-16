import SwiftUI
import Foundation

// MARK: - Shared badge
/// Glowing glass disc used by both confirmation sheets so they read as
/// two states of one component.
struct ConfirmationBadge: View {
    let systemImage: String
    let tint: Color

    var body: some View {
        ZStack {
            Circle()
                .fill(tint.opacity(0.14))
                .frame(width: 128, height: 128)
                .blur(radius: 8)

            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: 92, height: 92)
                .overlay {
                    Circle().fill(tint.opacity(0.18))
                }
                .overlay {
                    Circle().strokeBorder(Color.white.opacity(0.45), lineWidth: 1)
                }
                .shadow(color: tint.opacity(0.35), radius: 18, y: 8)

            Image(systemName: systemImage)
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(tint)
        }
    }
}

// MARK: - Mark used

struct MarkUsedConfirmationView: View {
    @EnvironmentObject var store: ShelfLifeStore
    @Environment(\.dismiss) private var dismiss
    let item: PantryItem
    var onDone: () -> Void

    var body: some View {
        VStack(spacing: 22) {
            Spacer()

            ConfirmationBadge(systemImage: "checkmark", tint: AppTheme.sage)

            VStack(spacing: 8) {
                Text("Nice — one less thing to waste")
                    .font(.title3).fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                Text("\(item.name) marked as used.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                Text("🎉").font(.title2)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Food saved")
                        .font(.caption2).fontWeight(.bold)
                        .tracking(0.6)
                        .foregroundStyle(AppTheme.sage)
                    Text("That's \(item.name) that didn't end up in the bin.")
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .glassCard(tint: AppTheme.sage, padding: 16)

            Spacer()

            Button("Done") {
                store.markUsed(item)
                dismiss()
                onDone()
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding(22)
        .background { AuroraBackground() }
    }
}

// MARK: - Start return

struct ReturnConfirmationView: View {
    @EnvironmentObject var store: ShelfLifeStore
    @Environment(\.dismiss) private var dismiss
    let item: PantryItem
    var onDone: () -> Void

    var body: some View {
        VStack(spacing: 22) {
            Spacer()

            ConfirmationBadge(systemImage: "arrow.uturn.backward", tint: AppTheme.teal)

            VStack(spacing: 8) {
                Text("Return started")
                    .font(.title3).fontWeight(.semibold)
                Text("We'll remind you to drop off the \(item.name) by \(item.expiryDate.formatted(date: .abbreviated, time: .omitted)).")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 0) {
                summaryRow("Item", item.name)
                GlassDivider()
                summaryRow("Store", item.source)
                GlassDivider()
                summaryRow("Deadline", item.expiryDate.formatted(date: .abbreviated, time: .omitted))
            }
            .glass(cornerRadius: AppTheme.cardRadius)

            Spacer()

            Button("Done") {
                store.startReturn(item)
                dismiss()
                onDone()
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding(22)
        .background { AuroraBackground() }
    }

    private func summaryRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(value).fontWeight(.semibold)
                .multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
        .padding(.horizontal, 18)
        .padding(.vertical, 13)
    }
}
