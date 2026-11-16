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

    /// Called on the main thread when a save or delete fails, with a
    /// message the person can read. ShelfLifeStore shows it as a banner.
    var onError: ((String) -> Void)?

    private func report(_ error: Error?, _ what: String) {
        guard let error else { return }
        print("Firestore \(what) error:", error.localizedDescription)
        let message: String
        switch FirestoreErrorCode.Code(rawValue: (error as NSError).code) {
        case .permissionDenied:
            message = "Couldn't \(what). The database rules don't allow it yet (see README)."
        case .unavailable, .deadlineExceeded:
            message = "Couldn't \(what). Check your internet connection."
        default:
            message = "Couldn't \(what). Try again."
        }
        DispatchQueue.main.async { self.onError?(message) }
    }

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
                self.report(error, "load your items")
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
            try itemsRef(for: userID).document(item.id).setData(from: item) { [weak self] error in
                self?.report(error, "save \(item.name)")
            }
        } catch {
            report(error, "save \(item.name)")
        }
    }

    func delete(_ item: PantryItem, userID: String) {
        itemsRef(for: userID).document(item.id).delete { [weak self] error in
            self?.report(error, "delete \(item.name)")
        }
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
            try historyRef(for: userID).document(entry.id).setData(from: entry) { [weak self] error in
                self?.report(error, "save your history")
            }
        } catch {
            report(error, "save your history")
        }
    }

    func deleteHistory(id: String, userID: String) {
        historyRef(for: userID).document(id).delete()
    }

    // MARK: Account document  (users/{userID})

    private func userRef(_ userID: String) -> DocumentReference {
        db.collection("users").document(userID)
    }

    /// Whether the starter items were already added for this account.
    /// Stored on the account, so it holds across phones and reinstalls.
    /// nil means the server couldn't be reached.
    func isSeeded(userID: String, completion: @escaping (Bool?) -> Void) {
        userRef(userID).getDocument(source: .server) { snapshot, error in
            if let error {
                print("Firestore account read error:", error.localizedDescription)
                completion(nil)
                return
            }
            completion(snapshot?.data()?["seeded"] as? Bool ?? false)
        }
    }

    func markSeeded(userID: String) {
        userRef(userID).setData(["seeded": true], merge: true) { [weak self] error in
            self?.report(error, "save your account settings")
        }
    }

    /// Deletes every item, every history entry and the account document.
    /// Used before deleting the account itself.
    func deleteAllData(userID: String, completion: @escaping (Error?) -> Void) {
        let group = DispatchGroup()
        var firstError: Error?

        for collection in [itemsRef(for: userID), historyRef(for: userID)] {
            group.enter()
            collection.getDocuments { snapshot, error in
                if let error {
                    firstError = firstError ?? error
                    group.leave()
                    return
                }
                let refs = snapshot?.documents.map(\.reference) ?? []
                // A batch holds at most 500 writes.
                let chunks = stride(from: 0, to: refs.count, by: 450).map {
                    Array(refs[$0..<min($0 + 450, refs.count)])
                }
                for chunk in chunks {
                    group.enter()
                    let batch = self.db.batch()
                    chunk.forEach { batch.deleteDocument($0) }
                    batch.commit { error in
                        if let error { firstError = firstError ?? error }
                        group.leave()
                    }
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            if let firstError {
                completion(firstError)
                return
            }
            self.userRef(userID).delete { error in
                completion(error)
            }
        }
    }

    /// Writes the starter items once, for a brand new account.
    func seedSampleData(userID: String) {
        for item in PantryItem.samples {
            save(item, userID: userID)
        }
    }
}
