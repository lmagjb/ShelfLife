import SwiftUI
import UIKit

struct SettingsView: View {
    @EnvironmentObject var auth: AuthService
    @EnvironmentObject var store: ShelfLifeStore
    @Environment(\.openURL) private var openURL

    // Saved on the phone. Same keys as ReminderSettings and RootView.
    @AppStorage(ReminderSettings.enabledKey) private var remindersEnabled = true
    @AppStorage(ReminderSettings.minutesKey) private var reminderMinutes = ReminderSettings.defaultMinutes
    @AppStorage(ReminderSettings.daysBeforeKey) private var reminderDaysBefore = ReminderSettings.defaultDaysBefore
    @AppStorage("appearance") private var appearance = "system"
    @AppStorage("autoDetectType") private var autoDetect = true

    @State private var isShowingProfile = false
    @State private var notificationsAllowed = true
    @State private var exportFile: ExportFile? = nil
    @State private var isShowingClearExpired = false

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 22) {
                    profileCard
                    remindersSection
                    appearanceSection

                    GlassSection("Scanning") {
                        toggleRow(icon: "viewfinder", tint: AppTheme.teal,
                                  title: "Auto-detect food vs. purchase", isOn: $autoDetect)
                    }

                    dataSection

                    GlassSection("About") {
                        GlassRow(icon: "pesosign", tint: AppTheme.sage,
                                 title: "Currency", value: "\(Money.code) (\(Money.symbol))", showsChevron: false)
                        GlassDivider()
                        GlassRow(icon: "info.circle.fill", tint: .secondary,
                                 title: "Version", value: appVersion, showsChevron: false)
                        GlassDivider()
                        NavigationLink {
                            PrivacyView()
                        } label: {
                            GlassRow(icon: "lock.fill", tint: .secondary, title: "Privacy Policy")
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 4)
                .padding(.bottom, 110)
            }
            .navigationTitle("Settings")
            .transparentChrome()
            .navigationDestination(isPresented: $isShowingProfile) {
                ProfileView()
            }
            .onAppear {
                ReminderManager.shared.checkPermission { notificationsAllowed = $0 }
            }
            // Any reminder setting change rebuilds the scheduled reminders.
            .onChange(of: remindersEnabled) { store.rescheduleReminders() }
            .onChange(of: reminderMinutes) { store.rescheduleReminders() }
            .onChange(of: reminderDaysBefore) { store.rescheduleReminders() }
            .sheet(item: $exportFile) { file in
                ShareSheet(items: [file.url])
            }
            .confirmationDialog("Delete \(store.expiredItems.count) expired items?",
                                isPresented: $isShowingClearExpired,
                                titleVisibility: .visible) {
                Button("Delete All", role: .destructive) {
                    store.deleteItems(store.expiredItems)
                }
                Button("Cancel", role: .cancel) { }
            }
        }
    }

    // MARK: Reminders

    private var remindersSection: some View {
        GlassSection("Reminders") {
            toggleRow(icon: "bell.fill", tint: AppTheme.amber,
                      title: "Expiry reminders", isOn: $remindersEnabled)

            if remindersEnabled {
                GlassDivider()
                settingRow(icon: "clock.fill", tint: AppTheme.amber, title: "Time") {
                    DatePicker("Time", selection: reminderTime, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .tint(AppTheme.sage)
                }
                GlassDivider()
                settingRow(icon: "calendar", tint: AppTheme.amber, title: "Remind me") {
                    Picker("Remind me", selection: $reminderDaysBefore) {
                        Text("On the day").tag(0)
                        Text("1 day before").tag(1)
                        Text("2 days before").tag(2)
                        Text("3 days before").tag(3)
                    }
                    .pickerStyle(.menu)
                    .tint(AppTheme.sage)
                }
            }

            if !notificationsAllowed {
                GlassDivider()
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        openURL(url)
                    }
                } label: {
                    GlassRow(icon: "exclamationmark.triangle.fill", tint: AppTheme.danger,
                             title: "Notifications are off. Turn on in iOS Settings")
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// The saved minutes-after-midnight shown as a time for the picker.
    private var reminderTime: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(bySettingHour: reminderMinutes / 60,
                                      minute: reminderMinutes % 60,
                                      second: 0, of: Date()) ?? Date()
            },
            set: { newValue in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                reminderMinutes = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
            }
        )
    }

    // MARK: Appearance

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("APPEARANCE")
                .font(.caption2).fontWeight(.semibold)
                .tracking(0.8)
                .foregroundStyle(.secondary)
                .padding(.leading, 6)

            GlassSegmentedControl(
                selection: $appearance,
                options: [("system", "System"), ("light", "Light"), ("dark", "Dark")]
            )
        }
    }

    // MARK: Data

    private var dataSection: some View {
        GlassSection("Data") {
            GlassRow(icon: "icloud.fill", tint: AppTheme.teal,
                     title: "Cloud sync", value: "On · Firebase", showsChevron: false)
            GlassDivider()
            Button {
                if let url = store.exportCSV() {
                    exportFile = ExportFile(url: url)
                }
            } label: {
                GlassRow(icon: "square.and.arrow.up.fill", tint: AppTheme.sage,
                         title: "Export all data (CSV)")
            }
            .buttonStyle(.plain)
            .disabled(store.items.isEmpty)

            if !store.expiredItems.isEmpty {
                GlassDivider()
                Button {
                    isShowingClearExpired = true
                } label: {
                    GlassRow(icon: "trash.fill", tint: AppTheme.coral,
                             title: "Clear expired items", value: "\(store.expiredItems.count)")
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: Profile card

    private var profileCard: some View {
        Button {
            isShowingProfile = true
        } label: {
            HStack(spacing: 14) {
                AvatarView(initials: initials, size: 56)

                VStack(alignment: .leading, spacing: 3) {
                    Text(displayName)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(auth.email)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Text("\(store.items.count) items tracked")
                        .font(.caption2).fontWeight(.semibold)
                        .foregroundStyle(AppTheme.sage)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.caption).fontWeight(.semibold)
                    .foregroundStyle(.tertiary)
            }
            .glassCard(tint: AppTheme.sage, padding: 16)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Profile, \(displayName)")
    }

    // MARK: Rows

    private func toggleRow(icon: String, tint: Color, title: String,
                           isOn: Binding<Bool>) -> some View {
        HStack(spacing: 13) {
            rowIcon(icon, tint)
            Toggle(title, isOn: isOn)
                .font(.subheadline)
                .tint(AppTheme.sage)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
    }

    /// Icon and title on the left, any control on the right.
    private func settingRow<Control: View>(icon: String, tint: Color, title: String,
                                           @ViewBuilder control: () -> Control) -> some View {
        HStack(spacing: 13) {
            rowIcon(icon, tint)
            Text(title).font(.subheadline)
            Spacer(minLength: 8)
            control()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }

    private func rowIcon(_ icon: String, _ tint: Color) -> some View {
        Image(systemName: icon)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: 30, height: 30)
            .background(Circle().fill(tint.opacity(0.16)))
            .accessibilityHidden(true)
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var displayName: String {
        String(auth.email.split(separator: "@").first ?? "Account")
    }

    private var initials: String {
        String((auth.email.split(separator: "@").first ?? "").prefix(2)).uppercased()
    }
}

// MARK: - Export helpers

/// Wraps the file URL so it can drive `.sheet(item:)`.
struct ExportFile: Identifiable {
    let id = UUID()
    let url: URL
}

/// The standard iOS share sheet (Save to Files, AirDrop, Mail…).
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

// MARK: - Privacy

struct PrivacyView: View {
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                privacyPoint("What we store",
                             "Your email for signing in, and the items you add: name, category, dates, price and notes.")
                privacyPoint("Where it's stored",
                             "In your own folder in Google Firebase, linked to your account. Other users can't see it.")
                privacyPoint("Photos",
                             "Receipt photos are read on your iPhone to fill in the form. The photo itself is never uploaded.")
                privacyPoint("Reminders",
                             "Reminders are scheduled on your iPhone. No reminder data leaves the device.")
                privacyPoint("Deleting your data",
                             "Delete items any time from the Vault. Export everything first from Settings → Data.")
            }
            .padding(.horizontal, 18)
            .padding(.top, 6)
            .padding(.bottom, 30)
        }
        .navigationTitle("Privacy Policy")
        .navigationBarTitleDisplayMode(.inline)
        .transparentChrome()
    }

    private func privacyPoint(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(padding: 18)
    }
}

// MARK: - Avatar
/// Gradient disc with a glass rim, shared by Settings and Profile.
struct AvatarView: View {
    let initials: String
    var size: CGFloat = 56

    var body: some View {
        Text(initials.isEmpty ? "?" : initials)
            .font(.system(size: size * 0.36, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background {
                Circle().fill(
                    LinearGradient(colors: [AppTheme.mint, AppTheme.teal],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                Circle().fill(
                    LinearGradient(colors: [Color.white.opacity(0.35), Color.white.opacity(0)],
                                   startPoint: .top, endPoint: .center)
                )
            }
            .overlay(Circle().strokeBorder(Color.white.opacity(0.45), lineWidth: 1.2))
            .shadow(color: AppTheme.teal.opacity(0.35), radius: 10, y: 5)
    }
}
