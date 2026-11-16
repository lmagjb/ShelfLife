import Foundation
import FirebaseFirestore

// MARK: - Firestore
/// Reads and writes items in the cloud.
/// Each account gets its own folder: users/{userID}/items/{itemID}
///
/// This is the only file that talks to the database. To use a different
/// database (for example SwiftData on the phone), write another class
/// with these same four functions and use it in ShelfLifeStore instead.
final class FirestoreService {

    private let db = Firestore.firestore()

    private func itemsRef(for userID: String) -> CollectionReference {
        db.collection("users").document(userID).collection("items")
    }

    /// Watches a user's items. `onChange` runs straight away with whatever
    /// is already saved, then again on every change — including changes
    /// made on another device.
    /// The second value says whether this batch came from the phone's
    /// cache rather than the server.
    /// Returns the listener so it can be stopped on sign-out.
    func listen(userID: String,
                onChange: @escaping ([PantryItem], Bool) -> Void) -> ListenerRegistration {

        return itemsRef(for: userID).addSnapshotListener { snapshot, error in
            if let error {
                print("Firestore listen error:", error.localizedDescription)
                return
            }
            guard let snapshot else { return }

            var items: [PantryItem] = []
            for doc in snapshot.documents {
                // The older app kept used items with isDone = true; the
                // current one deletes them. Hide those leftovers.
                if doc.data()["isDone"] as? Bool == true { continue }
                do {
                    items.append(try doc.data(as: PantryItem.self))
                } catch {
                    // Printed rather than ignored, so a bad document is
                    // visible in the console instead of silently vanishing.
                    print("Could not decode \(doc.documentID):", error)
                }
            }
            onChange(items, snapshot.metadata.isFromCache)
        }
    }

    func save(_ item: PantryItem, userID: String) {
        do {
            try itemsRef(for: userID).document(item.id).setData(from: item)
        } catch {
            print("Firestore save error:", error.localizedDescription)
        }
    }

    func delete(_ item: PantryItem, userID: String) {
        itemsRef(for: userID).document(item.id).delete()
    }

    // MARK: History  (users/{userID}/history/{itemID})

    private func historyRef(for userID: String) -> CollectionReference {
        db.collection("users").document(userID).collection("history")
    }

    func listenHistory(userID: String,
                       onChange: @escaping ([HistoryEntry]) -> Void) -> ListenerRegistration {
        return historyRef(for: userID).addSnapshotListener { snapshot, error in
            if let error {
                // Usually means the Firestore rules don't allow the
                // history folder yet. See READ-ME.txt.
                print("Firestore history error:", error.localizedDescription)
                return
            }
            guard let snapshot else { return }
            onChange(snapshot.documents.compactMap { try? $0.data(as: HistoryEntry.self) })
        }
    }

    func saveHistory(_ entry: HistoryEntry, userID: String) {
        do {
            try historyRef(for: userID).document(entry.id).setData(from: entry)
        } catch {
            print("Firestore history save error:", error.localizedDescription)
        }
    }

    func deleteHistory(id: String, userID: String) {
        historyRef(for: userID).document(id).delete()
    }

    /// Writes the starter items once, for a brand new account.
    func seedSampleData(userID: String) {
        for item in PantryItem.samples {
            save(item, userID: userID)
        }
    }
}
