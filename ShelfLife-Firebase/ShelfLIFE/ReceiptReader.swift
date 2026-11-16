import SwiftUI
import UIKit
import Vision

// MARK: - Receipt reader
/// Reads the text in a photo with Apple's Vision framework (on the
/// iPhone, no internet needed), then guesses the item name, store,
/// price and category. The guesses only fill in the form; the user
/// checks them before saving.
enum ReceiptReader {

    struct Result {
        var name: String
        var store: String
        var amount: Double?
        var category: ItemCategory
        var lineCount: Int
    }

    /// Runs text recognition off the main thread and calls back on it.
    static func read(_ image: UIImage, completion: @escaping (Result) -> Void) {
        guard let cgImage = image.cgImage else {
            completion(parse([]))
            return
        }

        let request = VNRecognizeTextRequest { request, _ in
            let observations = (request.results as? [VNRecognizedTextObservation]) ?? []
            // Vision measures from the bottom, so a higher midY is nearer
            // the top of the receipt. Sorting gives top-to-bottom order.
            let lines = observations
                .sorted { $0.boundingBox.midY > $1.boundingBox.midY }
                .compactMap { $0.topCandidates(1).first?.string }
            let result = parse(lines)
            DispatchQueue.main.async { completion(result) }
        }
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cgImage: cgImage,
                                            orientation: orientation(of: image),
                                            options: [:])
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
            } catch {
                print("Text recognition failed:", error.localizedDescription)
                DispatchQueue.main.async { completion(parse([])) }
            }
        }
    }

    // MARK: Guessing

    /// Lines with these words are totals, taxes or receipt details, not items.
    /// Short words carry spaces or colons so "tin" doesn't hide "tinapay".
    private static let skipWords = [
        "total", "vat", "tax", "change", "cash ", "cash:", "tender", "invoice",
        "receipt", "cashier", "date", "time", "thank", "tel:", "tel.", "tel no", "address",
        "card", "amount due", "discount", "qty", "official", "or no", "or#", "sales",
        "balance", "points", "member", "pos ", "pos:", "pos#", "permit", "serial", "tin:",
        "tin no", "tin#", "branch", "visa", "gcash", "maya", "payment", "items",
        "welcome", "www", ".com"
    ]

    static func parse(_ lines: [String]) -> Result {
        let cleaned = lines
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        let amount = findTotal(in: cleaned)

        // Lines that read like words, not codes or totals.
        let wordy = cleaned.filter { line in
            let lower = line.lowercased()
            let letters = line.filter { $0.isLetter }.count
            return letters >= 3
                && Double(letters) / Double(max(line.count, 1)) > 0.45
                && !skipWords.contains { lower.contains($0) }
        }

        // The store name is usually the first wordy line at the top.
        let store = wordy.first.map(tidy) ?? ""

        // An item line usually has a price on it ("Ninja Blender 3,499.00").
        // Otherwise take the first wordy line after the store name.
        let itemLine = wordy.dropFirst().first { money(in: $0) != nil }
            ?? wordy.dropFirst().first
            ?? wordy.first
            ?? ""
        let name = tidy(removeMoney(from: itemLine))

        return Result(name: name,
                      store: store,
                      amount: amount,
                      category: guessCategory(for: name.isEmpty ? store : name),
                      lineCount: cleaned.count)
    }

    /// The amount on the TOTAL line. Receipts often split "TOTAL" and the
    /// number into separate lines, so the next line is checked too.
    /// Failing that, the biggest amount that isn't cash or change.
    private static func findTotal(in lines: [String]) -> Double? {
        for (index, line) in lines.enumerated() {
            let lower = line.lowercased()
            guard lower.contains("total"), !lower.contains("subtotal") else { continue }
            if let value = money(in: line) { return value }
            if index + 1 < lines.count, let value = money(in: lines[index + 1]) { return value }
        }

        let ignore = ["cash", "change", "tender", "vat", "tax"]
        return lines
            .filter { line in !ignore.contains { line.lowercased().contains($0) } }
            .compactMap { money(in: $0) }
            .max()
    }

    /// The last money-looking number on a line: 3,499.00 or 89.50.
    private static func money(in line: String) -> Double? {
        let pattern = #"\d{1,3}(?:,\d{3})*\.\d{2}|\d+\.\d{2}"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(line.startIndex..., in: line)
        guard let match = regex.matches(in: line, range: range).last,
              let found = Range(match.range, in: line) else { return nil }
        return Double(line[found].replacingOccurrences(of: ",", with: ""))
    }

    private static func removeMoney(from line: String) -> String {
        line.replacingOccurrences(of: #"(₱|PHP|Php)?\s?\d[\d,]*\.\d{2}"#,
                                  with: "", options: .regularExpression)
    }

    /// Drops quantities and long product codes, trims symbols, and turns
    /// ALL CAPS into Title Case.
    private static func tidy(_ text: String) -> String {
        var result = text
            .replacingOccurrences(of: #"^\s*\d+\s*[xX@]\s*"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\b\d{5,}\b"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: " -*:#.,"))

        if result == result.uppercased() {
            result = result.capitalized
        }
        return result
    }

    // MARK: Category

    private static let keywords: [(ItemCategory, [String])] = [
        (.dairy,   ["milk", "gatas", "cheese", "keso", "yogurt", "yoghurt", "butter", "cream", "mantikilya"]),
        (.meat,    ["chicken", "manok", "pork", "baboy", "beef", "baka", "fish", "isda", "tuna", "bangus",
                    "tilapia", "shrimp", "hipon", " ham ", "hotdog", "bacon", "sausage", "longganisa", "tocino",
                    "liempo", "meat", "karne"]),
        (.bakery,  ["bread", "tinapay", "pandesal", "loaf", " bun", "cake", "croissant", "ensaymada", "muffin"]),
        (.produce, ["apple", "banana", "saging", "mango", "mangga", "orange", "grape", "fruit", "prutas",
                    "vegetable", "gulay", "lettuce", "spinach", "cabbage", "repolyo", "tomato", "kamatis",
                    "onion", "sibuyas", "garlic", "bawang", "carrot", "potato", "patatas", "kangkong",
                    "pechay", "ampalaya", "eggplant", "talong", "calamansi"]),
        (.pantry,  [" egg", "itlog", " rice", "bigas", "noodle", "pasta", "sardines", "corned", "coffee",
                    "sugar", "flour", " oil", "sauce", "soy", "vinegar", "cereal", "oats", "snack", "chips",
                    "biscuit", "juice", "soda", "water", "can "]),
        (.electronics, ["phone", "charger", "cable", "headphone", "earbud", "earphone", "blender", "speaker",
                        "laptop", "tablet", "mouse", "keyboard", "monitor", " tv", "television", "camera",
                        " fan", "rice cooker", "oven", "microwave", "airfryer", "air fryer", "power bank",
                        "watch", "router", "appliance", "electric"]),
        (.apparel, ["shirt", "tshirt", "t-shirt", "shoe", "sneaker", "pants", "jeans", "shorts", "dress",
                    "jacket", "hoodie", "socks", " cap ", " bag", "sandals", "slippers", "uniform"]),
        (.home,    ["pillow", "towel", "bedsheet", "curtain", "chair", "table", "lamp", " pan ", " pot ",
                    "plate", " mug", "glass", "broom", "mop", "detergent", "soap", "shampoo", "tissue"])
    ]

    /// Picks a category from keywords in the name. Unknown names count
    /// as a purchase, since groceries are usually easy to spot.
    static func guessCategory(for text: String) -> ItemCategory {
        let lower = " " + text.lowercased() + " "
        for (category, words) in keywords where words.contains(where: { lower.contains($0) }) {
            return category
        }
        return .home
    }

    // MARK: Photo orientation

    /// Phone photos are stored sideways with a flag saying which way is up.
    /// Vision needs that flag, or it reads the text at 90°.
    private static func orientation(of image: UIImage) -> CGImagePropertyOrientation {
        switch image.imageOrientation {
        case .up:            return .up
        case .down:          return .down
        case .left:          return .left
        case .right:         return .right
        case .upMirrored:    return .upMirrored
        case .downMirrored:  return .downMirrored
        case .leftMirrored:  return .leftMirrored
        case .rightMirrored: return .rightMirrored
        @unknown default:    return .up
        }
    }
}

// MARK: - Camera
/// The system camera, wrapped for SwiftUI. Not available in the
/// Simulator, so the scan screen also offers the photo library.
struct CameraPicker: UIViewControllerRepresentable {
    var onImage: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ picker: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker

        init(_ parent: CameraPicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImage(image)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
