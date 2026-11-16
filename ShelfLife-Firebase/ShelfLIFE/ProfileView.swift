import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var auth: AuthService
    @EnvironmentObject var store: ShelfLifeStore
    @Environment(\.dismiss) private var dismiss
    @State private var isShowingLogoutConfirm = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 22) {
                VStack(spacing: 13) {
                    AvatarView(initials: initials, size: 92)

                    VStack(spacing: 3) {
                        Text(displayName).font(.title3).fontWeight(.semibold)
                        Text(auth.email).font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 10)

                HStack(spacing: 10) {
                    statBox("\(store.items.count)", "Tracked", tint: AppTheme.teal)
                    statBox("\(store.pantryItems.count)", "In pantry", tint: AppTheme.sage)
                    statBox(Money.format(store.totalAtRisk), "At risk", tint: AppTheme.warning)
                }

                GlassSection("Account") {
                    GlassRow(icon: "person.fill", tint: AppTheme.teal, title: "Edit profile")
                    GlassDivider()
                    GlassRow(icon: "pesosign", tint: AppTheme.sage, title: "Change currency")
                    GlassDivider()
                    GlassRow(icon: "iphone", tint: AppTheme.violet, title: "Linked devices")
                }

                Button {
                    isShowingLogoutConfirm = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                        Text("Log Out")
                    }
                }
                .buttonStyle(PrimaryButtonStyle(color: AppTheme.danger))
                .padding(.top, 4)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 110)
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .transparentChrome()
        .confirmationDialog("Log out of ShelfLife?",
                            isPresented: $isShowingLogoutConfirm,
                            titleVisibility: .visible) {
            Button("Log Out", role: .destructive) {
                auth.signOut()
                dismiss()
            }
            Button("Cancel", role: .cancel) { }
        }
    }

    /// Name taken from the email, since there is no profile record yet.
    private var displayName: String {
        String(auth.email.split(separator: "@").first ?? "Account")
    }

    private var initials: String {
        String((auth.email.split(separator: "@").first ?? "").prefix(2)).uppercased()
    }

    private func statBox(_ value: String, _ label: String, tint: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 19, weight: .bold, design: .rounded))
                .lineLimit(1).minimumScaleFactor(0.7)
            Text(label)
                .font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 15)
        .glass(cornerRadius: 20, tint: tint, tintOpacity: 0.12,
               shadowRadius: 10, shadowOpacity: 0.07)
    }
}
