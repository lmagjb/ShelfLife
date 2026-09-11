//
//  SheetViews.swift
//  ShelfLIFE
//

import SwiftUI

// MARK: - Scan
/// A pretend camera. Tapping the shutter fills in the details, the same
/// way real text recognition would.
struct ScanView: View {
    @EnvironmentObject var data: AppData
    @Environment(\.dismiss) var dismiss

    @State private var scanned = false
    @State private var kind: ItemKind = .purchase
    @State private var name = ""

    var body: some View {
        VStack(spacing: 0) {

            // Fake viewfinder
            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(AppColor.dark)
                VStack(spacing: 12) {
                    Image(systemName: "doc.text.viewfinder")
                        .font(.system(size: 44))
                        .foregroundColor(.white.opacity(0.4))
                    Text(scanned ? "Got it" : "Point at a receipt or product")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .padding(20)

            if scanned {
                resultForm
            } else {
                shutter
            }
        }
        .background(AppColor.background)
    }

    private var shutter: some View {
        Button {
            kind = .purchase
            name = "Ninja Blender"
            scanned = true
        } label: {
            Circle()
                .fill(Color.white)
                .frame(width: 70, height: 70)
                .overlay(Circle().stroke(AppColor.gray, lineWidth: 4))
        }
        .padding(.bottom, 40)
    }

    private var resultForm: some View {
        VStack(spacing: 14) {
            Picker("Type", selection: $kind) {
                ForEach(ItemKind.allCases) { k in
                    Text("\(k.emoji) \(k.rawValue)").tag(k)
                }
            }
            .pickerStyle(.segmented)

            TextField("Item name", text: $name)
                .padding(14)
                .cardStyle()

            HStack(spacing: 10) {
                OutlineButton(title: "Retake") { scanned = false }
                FilledButton(title: "Save", color: AppColor.green) {
                    data.add(name: name,
                             kind: kind,
                             category: kind == .food ? "Dairy" : "Home",
                             store: kind == .food ? "Pantry" : "Ace Home Center",
                             days: kind == .food ? 7 : 30,
                             price: kind == .food ? 120 : 3499)
                    dismiss()
                }
            }
        }
        .padding(20)
    }
}

// MARK: - Add by hand
struct AddItemView: View {
    @EnvironmentObject var data: AppData
    @Environment(\.dismiss) var dismiss

    @State private var name = ""
    @State private var kind: ItemKind = .food
    @State private var category = "Dairy"
    @State private var store = ""
    @State private var days = 7
    @State private var price = ""

    let foodCategories = ["Dairy", "Vegetables", "Meat", "Bakery", "Fruits"]
    let buyCategories = ["Home", "Electronics", "Apparel"]

    var categories: [String] {
        kind == .food ? foodCategories : buyCategories
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Item") {
                    TextField("Name", text: $name)

                    Picker("Type", selection: $kind) {
                        ForEach(ItemKind.allCases) { k in
                            Text(k.rawValue).tag(k)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: kind) { _, newKind in
                        category = newKind == .food ? "Dairy" : "Home"
                    }

                    Picker("Category", selection: $category) {
                        ForEach(categories, id: \.self) { Text($0) }
                    }
                }

                Section(kind == .food ? "Expires" : "Deadline") {
                    Stepper("In \(days) days", value: $days, in: 1...365)
                }

                Section("Optional") {
                    TextField(kind == .food ? "Where it's kept" : "Store", text: $store)
                    TextField("Price", text: $price)
                        .keyboardType(.numberPad)
                }
            }
            .navigationTitle("Add Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        data.add(name: name, kind: kind, category: category,
                                 store: store, days: days,
                                 price: Double(price) ?? 0)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

// MARK: - Settings
struct SettingsView: View {
    @EnvironmentObject var data: AppData
    @EnvironmentObject var auth: AuthService
    @Environment(\.dismiss) var dismiss

    /// First two letters of the email, so "ben@mail.com" shows as "BE".
    private var initials: String {
        let name = auth.email.split(separator: "@").first ?? ""
        return String(name.prefix(2)).uppercased()
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Account") {
                    HStack(spacing: 14) {
                        Circle()
                            .fill(AppColor.brown)
                            .frame(width: 50, height: 50)
                            .overlay(
                                Text(initials)
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                            )
                        VStack(alignment: .leading, spacing: 2) {
                            Text(auth.email)
                                .font(.system(size: 15, weight: .semibold))
                                .lineLimit(1)
                            Text("\(data.items.count) items tracked")
                                .font(.system(size: 12))
                                .foregroundColor(AppColor.gray)
                        }
                    }
                    .padding(.vertical, 4)

                    Button("Sign Out", role: .destructive) {
                        auth.signOut()
                        dismiss()
                    }
                }

                Section("Preferences") {
                    Toggle("Notifications", isOn: $data.notificationsOn)
                    Toggle("Auto-detect item type", isOn: $data.autoDetectOn)
                    Toggle("iCloud Sync", isOn: $data.iCloudOn)
                }

                Section("Data") {
                    Button("Reset to sample data") {
                        data.reset()
                    }
                }

                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0").foregroundColor(AppColor.gray)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    AddItemView()
        .environmentObject(AppData())
}
