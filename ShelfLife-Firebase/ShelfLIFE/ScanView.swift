import SwiftUI
import Foundation
import PhotosUI

/// Take a photo of a receipt or label (or pick one from Photos). The text
/// is read on the phone and fills in the form below, which the user
/// checks before adding the item.
struct ScanView: View {
    @EnvironmentObject var store: ShelfLifeStore
    @Environment(\.dismiss) private var dismiss
    @AppStorage("autoDetectType") private var autoDetect = true

    @State private var photo: UIImage? = nil
    @State private var photoItem: PhotosPickerItem? = nil
    @State private var isShowingCamera = false
    @State private var isShowingBarcode = false

    @State private var isScanning = false
    @State private var hasDetected = false
    @State private var scanLine: CGFloat = 0
    @State private var statusMessage = ""

    @State private var detectedType: ItemType = .purchase
    @State private var detectedCategory: ItemCategory = .electronics
    @State private var detectedName = ""
    @State private var detectedStore = ""
    @State private var detectedAmount = ""

    private var cameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    private var canAdd: Bool {
        !detectedName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    viewfinder

                    if hasDetected {
                        detectedCard
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    } else {
                        captureButtons
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)
                .padding(.bottom, 30)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Scan Item")
            .navigationBarTitleDisplayMode(.inline)
            .transparentChrome()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                        .buttonStyle(GlassIconButtonStyle(size: 34))
                        .accessibilityLabel("Close")
                }
                if hasDetected {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Rescan") { reset() }
                            .font(.subheadline).fontWeight(.semibold)
                            .foregroundStyle(AppTheme.sage)
                    }
                }
            }
            .fullScreenCover(isPresented: $isShowingBarcode) {
                barcodeScreen
            }
            .fullScreenCover(isPresented: $isShowingCamera) {
                CameraPicker { image in scan(image) }
                    .ignoresSafeArea()
            }
            .onChange(of: photoItem) { _, newItem in
                guard let newItem else { return }
                Task { @MainActor in
                    if let data = try? await newItem.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        scan(image)
                    } else {
                        statusMessage = "Couldn't open that photo. Try another one."
                    }
                    photoItem = nil
                }
            }
        }
    }

    // MARK: Viewfinder

    private var viewfinder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(.ultraThinMaterial)

            if let photo {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                    .opacity(hasDetected ? 0.55 : 1)
                    .accessibilityHidden(true)
            }

            cornerBrackets
                .padding(18)

            if isScanning {
                GeometryReader { geo in
                    Capsule()
                        .fill(
                            LinearGradient(colors: [AppTheme.mint.opacity(0), AppTheme.mint, AppTheme.mint.opacity(0)],
                                           startPoint: .leading, endPoint: .trailing)
                        )
                        .frame(height: 3)
                        .shadow(color: AppTheme.mint, radius: 8)
                        .offset(y: geo.size.height * scanLine)
                }
                .padding(28)
            }

            if photo == nil && !hasDetected {
                VStack(spacing: 10) {
                    Image(systemName: isScanning ? "barcode.viewfinder" : "doc.viewfinder")
                        .font(.system(size: 36, weight: .light))
                        .foregroundStyle(AppTheme.sage)
                    Text(isScanning ? "Looking up the product…"
                                    : "Take a photo of a receipt,\nor scan a product barcode")
                        .font(.subheadline).fontWeight(.medium)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }
            } else if hasDetected {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(AppTheme.sage)
                    Text("Check the details below").font(.headline)
                }
                .padding(14)
                .glass(cornerRadius: 20, shadowRadius: 8, shadowOpacity: 0.08)
            }
        }
        .frame(height: hasDetected ? 180 : 340)
        .overlay {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .strokeBorder(Color.white.opacity(0.4), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.1), radius: 20, y: 10)
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: hasDetected)
    }

    private var cornerBrackets: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height, l: CGFloat = 30
            Path { p in
                p.move(to: CGPoint(x: 0, y: l)); p.addLine(to: .zero); p.addLine(to: CGPoint(x: l, y: 0))
                p.move(to: CGPoint(x: w - l, y: 0)); p.addLine(to: CGPoint(x: w, y: 0)); p.addLine(to: CGPoint(x: w, y: l))
                p.move(to: CGPoint(x: 0, y: h - l)); p.addLine(to: CGPoint(x: 0, y: h)); p.addLine(to: CGPoint(x: l, y: h))
                p.move(to: CGPoint(x: w - l, y: h)); p.addLine(to: CGPoint(x: w, y: h)); p.addLine(to: CGPoint(x: w, y: h - l))
            }
            .stroke(AppTheme.sage, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
        }
    }

    // MARK: Capture

    private var captureButtons: some View {
        VStack(spacing: 12) {
            if cameraAvailable {
                Button {
                    isShowingCamera = true
                } label: {
                    Label("Take Photo", systemImage: "camera.fill")
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(isScanning)
            }

            if BarcodeScanner.isUsable {
                Button {
                    isShowingBarcode = true
                } label: {
                    Label("Scan Barcode", systemImage: "barcode.viewfinder")
                }
                .buttonStyle(SecondaryButtonStyle())
                .disabled(isScanning)
            }

            PhotosPicker(selection: $photoItem, matching: .images) {
                Label("Choose from Photos", systemImage: "photo.on.rectangle")
            }
            .buttonStyle(SecondaryButtonStyle())
            .disabled(isScanning)

            Button("Type it in instead") {
                fillForm(with: nil)
            }
            .font(.subheadline).fontWeight(.semibold)
            .foregroundStyle(AppTheme.sage)
            .padding(.top, 2)

            if !cameraAvailable {
                Text("The camera isn't available in the Simulator. Drag a receipt photo into the Simulator's Photos app, then choose it here.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }

            if !statusMessage.isEmpty {
                Text(statusMessage)
                    .font(.caption).fontWeight(.medium)
                    .foregroundStyle(AppTheme.danger)
            }
        }
    }

    // MARK: Barcode

    /// Full-screen barcode camera with a hint and a close button.
    private var barcodeScreen: some View {
        ZStack(alignment: .top) {
            BarcodeScanner { code in
                isShowingBarcode = false
                lookUp(barcode: code)
            }
            .ignoresSafeArea()

            HStack {
                Button { isShowingBarcode = false } label: { Image(systemName: "xmark") }
                    .buttonStyle(GlassIconButtonStyle(size: 38))
                    .accessibilityLabel("Close")
                Spacer()
                Text("Point at the barcode")
                    .font(.subheadline).fontWeight(.semibold)
                    .padding(.horizontal, 14).padding(.vertical, 9)
                    .glass(cornerRadius: 18, material: .regularMaterial, shadowRadius: 6, shadowOpacity: 0.1)
                Spacer()
                // Balances the close button so the hint stays centred.
                Color.clear.frame(width: 38, height: 38)
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
        }
    }

    /// Finds the product name online, then fills in the form.
    private func lookUp(barcode: String) {
        photo = nil
        statusMessage = ""
        isScanning = true
        scanLine = 0
        withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
            scanLine = 1
        }

        Task { @MainActor in
            let product = await ProductLookup.find(barcode: barcode)
            isScanning = false

            detectedName = product?.name ?? ""
            detectedStore = product?.brand ?? ""
            detectedAmount = ""

            // Open Food Facts lists groceries, so a match is food.
            let guess = ReceiptReader.guessCategory(for: product?.name ?? "")
            detectedType = .food
            detectedCategory = guess.isFood ? guess : .pantry

            statusMessage = product == nil
                ? "Barcode \(barcode) isn't in the product database. Type the name below."
                : "Found by barcode. Check the details, then add it."

            withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) { hasDetected = true }
        }
    }

    // MARK: Result panel

    private var detectedCard: some View {
        VStack(alignment: .leading, spacing: 15) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Detected: \(detectedType == .purchase ? "Purchase" : "Food")")
                    .font(.headline)
                Text(statusMessage.isEmpty ? "Fix anything that's wrong, then add it." : statusMessage)
                    .font(.caption).foregroundStyle(.secondary)
            }

            GlassSegmentedControl(
                selection: $detectedType,
                options: [(.food, "Food"), (.purchase, "Purchase")]
            )

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ItemCategory.categories(for: detectedType)) { category in
                        Button {
                            detectedCategory = category
                        } label: {
                            FilterChip(title: "\(category.emoji) \(category.rawValue)",
                                       isSelected: detectedCategory == category)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 2)
            }

            inputWell(icon: "tag", placeholder: "Item name", text: $detectedName)
            inputWell(icon: "storefront", placeholder: "Store (optional)", text: $detectedStore)
            inputWell(icon: "pesosign", placeholder: "Price (optional)", text: $detectedAmount)
                .keyboardType(.decimalPad)

            Text(detectedType == .food
                 ? "Expiry is set to 5 days from today. You can change it after adding."
                 : "Return window is set to 30 days from today. You can change it after adding.")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Button("Add to ShelfLife") { addDetectedItem() }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!canAdd)
                .opacity(canAdd ? 1 : 0.5)
                .padding(.top, 2)
        }
        .glassCard(cornerRadius: 28, padding: 20)
        .onChange(of: detectedType) { _, newType in
            if detectedCategory.isFood != (newType == .food) {
                detectedCategory = ItemCategory.defaultCategory(for: newType)
            }
        }
    }

    private func inputWell(icon: String, placeholder: String, text: Binding<String>) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 18)
                .accessibilityHidden(true)
            TextField(placeholder, text: text)
                .font(.subheadline)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.primary.opacity(0.05))
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.22), lineWidth: 1)
        }
    }

    // MARK: Logic

    private func scan(_ image: UIImage) {
        photo = image
        statusMessage = ""
        isScanning = true
        scanLine = 0
        withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
            scanLine = 1
        }

        ReceiptReader.read(image) { result in
            fillForm(with: result)
        }
    }

    /// Puts what was read into the form. `nil` means "type it in".
    private func fillForm(with result: ReceiptReader.Result?) {
        isScanning = false

        if let result {
            detectedName = result.name
            detectedStore = result.store
            detectedAmount = result.amount.map { $0 == $0.rounded() ? String(Int($0)) : String($0) } ?? ""

            if autoDetect {
                detectedType = result.category.isFood ? .food : .purchase
                detectedCategory = result.category
            } else if result.category.isFood == (detectedType == .food) {
                detectedCategory = result.category
            }

            statusMessage = result.lineCount == 0
                ? "No text found. Type the details in below."
                : (result.name.isEmpty ? "Couldn't find the item name. Type it in below." : "")
        } else {
            detectedName = ""
            detectedStore = ""
            detectedAmount = ""
            statusMessage = ""
        }

        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) { hasDetected = true }
    }

    private func reset() {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
            hasDetected = false
            photo = nil
            statusMessage = ""
        }
    }

    private func addDetectedItem() {
        let days = detectedType == .purchase ? 30 : 5
        let expiry = Calendar.current.date(byAdding: .day, value: days, to: Date()) ?? Date()
        let amount = Double(detectedAmount.replacingOccurrences(of: ",", with: ""))
        let storeName = detectedStore.trimmingCharacters(in: .whitespaces)

        let item = PantryItem(
            name: detectedName.trimmingCharacters(in: .whitespaces),
            emoji: detectedCategory.emoji,
            category: detectedCategory,
            type: detectedType,
            source: storeName.isEmpty ? "Scanned" : storeName,
            purchasedDate: Date(),
            expiryDate: expiry,
            amount: (amount ?? 0) > 0 ? amount : nil
        )
        store.addItem(item)
        dismiss()
    }
}
