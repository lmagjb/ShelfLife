import SwiftUI

struct NotificationsView: View {
    @EnvironmentObject var store: ShelfLifeStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 10) {
                        if store.notifications.isEmpty {
                            GlassEmptyState(
                                emoji: "🔔",
                                title: "You're all caught up",
                                message: "Reminders about expiring food and closing return windows show up here."
                            )
                        } else {
                            ForEach(store.notifications) { notification in
                                NavigationLink(value: notification.id) {
                                    row(notification)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 8)
                }
            }
            .navigationDestination(for: String.self) { id in
                if let item = store.items.first(where: { $0.id == id }) {
                    ItemDetailView(item: item)
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .transparentChrome()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                        .buttonStyle(GlassIconButtonStyle(size: 34))
                        .accessibilityLabel("Close")
                }
            }
        }
    }

    private func row(_ notification: AppNotification) -> some View {
        HStack(alignment: .top, spacing: 13) {
            Text(notification.emoji)
                .font(.system(size: 18))
                .frame(width: 42, height: 42)
                .background {
                    Circle().fill(.ultraThinMaterial)
                    Circle().strokeBorder(Color.white.opacity(0.35), lineWidth: 1)
                }

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(notification.title)
                        .font(.subheadline).fontWeight(.semibold)
                    Spacer(minLength: 8)
                    Text(notification.timeAgo)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                Text(notification.message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Image(systemName: "chevron.right")
                .font(.caption2).fontWeight(.semibold)
                .foregroundStyle(.tertiary)
                .padding(.top, 4)
        }
        .padding(14)
        .glass(cornerRadius: 20, shadowRadius: 10, shadowOpacity: 0.07)
    }
}
