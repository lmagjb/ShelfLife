import SwiftUI
import VisionKit

// MARK: - Barcode camera
/// Apple's live scanner (VisionKit). It finds a barcode in the camera
/// view and hands back the number printed under it.
/// Real iPhone only: the Simulator has no camera.
struct BarcodeScanner: UIViewControllerRepresentable {
    var onCode: (String) -> Void

    /// False in the Simulator, on very old iPhones, or when camera
    /// access was refused.
    static var isUsable: Bool {
        DataScannerViewController.isSupported && DataScannerViewController.isAvailable
    }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.barcode()],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ scanner: DataScannerViewController, context: Context) {
        try? scanner.startScanning()
    }

    static func dismantleUIViewController(_ scanner: DataScannerViewController, coordinator: Coordinator) {
        scanner.stopScanning()
    }

    func makeCoordinator() -> Coordinator { Coordinator(onCode: onCode) }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onCode: (String) -> Void
        /// Stops the same barcode being reported many times a second.
        private var hasReported = false

        init(onCode: @escaping (String) -> Void) { self.onCode = onCode }

        func dataScanner(_ dataScanner: DataScannerViewController,
                         didAdd addedItems: [RecognizedItem],
                         allItems: [RecognizedItem]) {
            guard !hasReported else { return }
            for item in addedItems {
                if case .barcode(let barcode) = item, let code = barcode.payloadStringValue {
                    hasReported = true
                    onCode(code)
                    return
                }
            }
        }
    }
}

// MARK: - Product lookup
/// Looks a barcode up in Open Food Facts, a free public database of
/// food products. Needs internet. Many local products aren't listed,
/// so "not found" is normal and the user types the name instead.
enum ProductLookup {

    struct Product {
        var name: String
        var brand: String
    }

    static func find(barcode: String) async -> Product? {
        let digits = barcode.filter { $0.isNumber }
        guard !digits.isEmpty,
              let url = URL(string: "https://world.openfoodfacts.org/api/v2/product/\(digits).json?fields=product_name,brands")
        else { return nil }

        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        request.setValue("ShelfLife iOS student project", forHTTPHeaderField: "User-Agent")

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let product = json["product"] as? [String: Any] else { return nil }

            let name = (product["product_name"] as? String ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let brand = (product["brands"] as? String ?? "")
                .components(separatedBy: ",").first?
                .trimmingCharacters(in: .whitespaces) ?? ""

            return name.isEmpty ? nil : Product(name: name, brand: brand)
        } catch {
            print("Barcode lookup failed:", error.localizedDescription)
            return nil
        }
    }
}
