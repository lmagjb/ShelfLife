import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var auth: AuthService
    @EnvironmentObject var store: ShelfLifeStore
    @Environment(\.dismiss) private var dismiss
    @AppStorage(Money.currencyKey) private var currencyCode = Money.defaultCode

    @State private var isShowingLogoutConfirm = false
    @State private var isShowingEditName = false
    @State private var isShowingDeleteAccount = false
    @State private var statusMessage = ""

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 22) {
                VStack(spacing: 13) {
                    AvatarView(initials: auth.initials, size: 92)

                    VStack(spacing: 3) {
                        Text(auth.displayName).font(.title3).fontWeight(.semibold)
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
                    Button { isShowingEditName = true } label: {
                        GlassRow(icon: "person.fill", tint: AppTheme.teal,
                                 title: "Edit name", value: auth.displayName)
                    }
                    .buttonStyle(.plain)

                    GlassDivider()

                    HStack(spacing: 13) {
                        Image(systemName: "banknote.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AppTheme.sage)
                            .frame(width: 30, height: 30)
                            .background(Circle().fill(AppTheme.sage.opacity(0.16)))
                            .accessibilityHidden(true)
                        Text("Currency").font(.subheadline)
                        Spacer(minLength: 8)
                        Picker("Currency", selection: $currencyCode) {
                            ForEach(Money.choices, id: \.self) { code in
                                Text(code).tag(code)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(AppTheme.sage)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)

                    GlassDivider()

                    Button {
                        auth.resetPassword(email: auth.email)
                        statusMessage = "We sent a password reset link to \(auth.email)."
                    } label: {
                        GlassRow(icon: "key.fill", tint: AppTheme.violet, title: "Change password")
                    }
                    .buttonStyle(.plain)
                }

                if !statusMessage.isEmpty {
                    Text(statusMessage)
                        .font(.caption).fontWeight(.medium)
                        .foregroundStyle(AppTheme.sage)
                        .multilineTextAlignment(.center)
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

                Button("Delete Account") { isShowingDeleteAccount = true }
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundStyle(AppTheme.danger)
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
        .sheet(isPresented: $isShowingEditName) {
            EditNameView(currentName: auth.displayName)
        }
        .sheet(isPresented: $isShowingDeleteAccount) {
            DeleteAccountView()
        }
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

// MARK: - Edit name

struct EditNameView: View {
    @EnvironmentObject var auth: AuthService
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var error = ""
    @State private var isSaving = false

    init(currentName: String) {
        _name = State(initialValue: currentName)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                GlassSection("Your name") {
                    TextField("Name", text: $name)
                        .font(.subheadline)
                        .textContentType(.name)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 15)
                }

                if !error.isEmpty {
                    Text(error).font(.caption).foregroundStyle(AppTheme.danger)
                }

                Button {
                    isSaving = true
                    auth.updateDisplayName(name) { message in
                        isSaving = false
                        if let message { error = message } else { dismiss() }
                    }
                } label: {
                    if isSaving { ProgressView().tint(.white) } else { Text("Save") }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(isSaving || name.trimmingCharacters(in: .whitespaces).isEmpty)

                Spacer()
            }
            .padding(18)
            .navigationTitle("Edit Name")
            .navigationBarTitleDisplayMode(.inline)
            .transparentChrome()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                        .buttonStyle(GlassIconButtonStyle(size: 34))
                        .accessibilityLabel("Close")
                }
            }
        }
    }
}

// MARK: - Delete account
/// Required by the App Store for any app that lets people create an
/// account. Deletes every item, the history and the login itself.

struct DeleteAccountView: View {
    @EnvironmentObject var auth: AuthService
    @EnvironmentObject var store: ShelfLifeStore
    @Environment(\.dismiss) private var dismiss
    @State private var password = ""
    @State private var error = ""

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("This can't be undone").font(.headline)
                    Text("Your \(store.items.count) items, your history and your login are deleted from ShelfLife on every device. Export your data from Settings first if you want a copy.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                GlassSection("Enter your password to confirm") {
                    SecureField("Password", text: $password)
                        .font(.subheadline)
                        .textContentType(.password)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 15)
                }

                if !error.isEmpty {
                    Text(error).font(.caption).foregroundStyle(AppTheme.danger)
                }

                Button {
                    error = ""
                    auth.deleteAccount(password: password,
                                       deleteData: { userID, done in
                                           store.deleteAllData(userID: userID, completion: done)
                                       },
                                       completion: { message in
                                           if let message { error = message } else { dismiss() }
                                       })
                } label: {
                    if auth.isWorking { ProgressView().tint(.white) } else { Text("Delete My Account") }
                }
                .buttonStyle(PrimaryButtonStyle(color: AppTheme.danger))
                .disabled(auth.isWorking || password.isEmpty)

                Spacer()
            }
            .padding(18)
            .navigationTitle("Delete Account")
            .navigationBarTitleDisplayMode(.inline)
            .transparentChrome()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                        .buttonStyle(GlassIconButtonStyle(size: 34))
                        .accessibilityLabel("Close")
                }
            }
        }
    }
}
