import SwiftUI

enum AppTab: CaseIterable {
    case home, vault, insights, settings

    var label: String {
        switch self {
        case .home:     return "Home"
        case .vault:    return "Vault"
        case .insights: return "Insights"
        case .settings: return "Settings"
        }
    }

    var icon: String {
        switch self {
        case .home:     return "house"
        case .vault:    return "archivebox"
        case .insights: return "chart.bar"
        case .settings: return "gearshape"
        }
    }

    var filledIcon: String { icon + ".fill" }
}

struct MainTabView: View {
    @EnvironmentObject var store: ShelfLifeStore
    @State private var selectedTab: AppTab = .home
    @State private var isShowingScan = false
    @Namespace private var tabNamespace

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch selectedTab {
                case .home:     DashboardView()
                case .vault:    VaultView()
                case .insights: InsightsView()
                case .settings: SettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            tabBar
        }
        .overlay(alignment: .bottom) {
            if !store.recentlyDeleted.isEmpty {
                UndoToast(message: undoMessage) {
                    withAnimation { store.undoDelete() }
                }
                // Sits just above the floating tab bar.
                .padding(.bottom, 92)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85),
                   value: store.recentlyDeleted.map(\.id))
        // Hides the bar 4 seconds after the latest delete. A new delete
        // restarts the timer because the ids change.
        .task(id: store.recentlyDeleted.map(\.id)) {
            let ids = store.recentlyDeleted.map(\.id)
            guard !ids.isEmpty else { return }
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            await MainActor.run { store.clearUndo(ifMatching: ids) }
        }
        .sheet(isPresented: $isShowingScan) {
            ScanView()
        }
    }

    private var undoMessage: String {
        let deleted = store.recentlyDeleted
        if deleted.count == 1, let item = deleted.first {
            return "\(item.name) deleted"
        }
        return "\(deleted.count) items deleted"
    }

    // MARK: Floating glass tab bar

    private var tabBar: some View {
        HStack(spacing: 2) {
            tabButton(.home)
            tabButton(.vault)
            scanButton
            tabButton(.insights)
            tabButton(.settings)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .glass(cornerRadius: 30, shadowRadius: 22, shadowOpacity: 0.16)
        .padding(.horizontal, 16)
        .padding(.bottom, 6)
    }

    private func tabButton(_ tab: AppTab) -> some View {
        let isSelected = selectedTab == tab

        return Button {
            withAnimation(.spring(response: 0.34, dampingFraction: 0.76)) {
                selectedTab = tab
            }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: isSelected ? tab.filledIcon : tab.icon)
                    .font(.system(size: 17, weight: .medium))
                    .frame(height: 20)

                Text(tab.label)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .medium))
            }
            .foregroundStyle(isSelected ? AppTheme.sage : Color.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(AppTheme.sage.opacity(0.14))
                        .matchedGeometryEffect(id: "tab", in: tabNamespace)
                }
            }
        }
        .buttonStyle(.plain)
    }

    /// Raised capture button. It breaks the top edge of the bar so the
    /// primary action reads as the one thing sitting above the glass.
    private var scanButton: some View {
        Button {
            isShowingScan = true
        } label: {
            Image(systemName: "viewfinder")
                .font(.system(size: 21, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 54, height: 54)
                .background {
                    Circle().fill(
                        LinearGradient(colors: [AppTheme.mint, AppTheme.sage],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    Circle().fill(
                        LinearGradient(colors: [Color.white.opacity(0.4), Color.white.opacity(0)],
                                       startPoint: .top, endPoint: .center)
                    )
                }
                .overlay {
                    Circle().strokeBorder(Color.white.opacity(0.45), lineWidth: 1.2)
                }
                .shadow(color: AppTheme.sage.opacity(0.5), radius: 14, y: 7)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Scan item")
        .frame(width: 66)
        .offset(y: -14)
    }
}
