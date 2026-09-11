//
//  DataService.swift
//  ShelfLIFE
//
//  Created by Mac-LAB on 9/11/26.
//

import Foundation
import FirebaseFirestore

// MARK: - Firestore

class DataService {

    private let db = Firestore.firestore()

    /// Path to one user's items.
    private func itemsRef(for userID: String) -> CollectionReference {
        db.collection("users").document(userID).collection("items")
    }

    /// Watches a user's items and calls `onChange` every time they change —
    /// including right away with whatever is already saved.
    /// Returns the listener so it can be stopped on sign-out.
    func listen(userID: String,
                onChange: @escaping ([ShelfItem]) -> Void) -> ListenerRegistration {

        print("👂 Listening at users/\(userID)/items")

        return itemsRef(for: userID).addSnapshotListener { snapshot, error in
            if let error {
                print("❌ Listen error:", error.localizedDescription)
                return
            }
            guard let documents = snapshot?.documents else {
                print("❌ No snapshot returned")
                return
            }

            print("📄 Firestore returned \(documents.count) documents")

            var items: [ShelfItem] = []
            for doc in documents {
                do {
                    let item = try doc.data(as: ShelfItem.self)
                    items.append(item)
                } catch {
                    // This is what the old `try?` was hiding.
                    print("❌ Could not decode \(doc.documentID):", error)
                }
            }

            print("✅ Decoded \(items.count) items")
            onChange(items)
        }
    }

    func save(_ item: ShelfItem, userID: String) {
        do {
            try itemsRef(for: userID).document(item.id).setData(from: item)
        } catch {
            print("Firestore save error:", error.localizedDescription)
        }
    }

    func delete(_ item: ShelfItem, userID: String) {
        itemsRef(for: userID).document(item.id).delete()
    }

    /// Writes the sample items once, for a brand new account.
    func seedSampleData(userID: String) {
        for item in SampleData.items {
            save(item, userID: userID)
        }
    }
}
