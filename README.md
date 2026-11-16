# ShelfLife

An iPhone app that tracks when food expires and when purchases can still be
returned or claimed under warranty. Built with SwiftUI and Firebase
(Auth + Firestore).

The Xcode project is in [`ShelfLife-Firebase/`](ShelfLife-Firebase).
The change history is in [`ShelfLife-Firebase/READ-ME.txt`](ShelfLife-Firebase/READ-ME.txt).

## Requirements

- A Mac with **Xcode 16 or newer**. Firebase 12 does not build with older versions.
- iOS 17 or newer (Simulator or iPhone).
- The camera and barcode scanner only work on a real iPhone. In the Simulator,
  drag a receipt photo into Photos and use **Choose from Photos**.

## Run it

1. Open `ShelfLife-Firebase/ShelfLIFE.xcodeproj`.
2. Wait for Swift Package Manager to fetch Firebase (first open only).
3. Pick an iPhone simulator and press **Cmd+R**.

## Firebase setup (one time)

1. Firebase console > Authentication > Sign-in method > enable **Email/Password**.
2. Firestore Database > Rules > paste [`firestore.rules`](ShelfLife-Firebase/firestore.rules) > **Publish**.
3. Recommended, because this repository is public and includes
   `GoogleService-Info.plist`:
   - Google Cloud console > APIs & Services > Credentials > restrict the iOS API key
     to the bundle ID `com.shelflife.ShelfLIFE`.
   - Turn on Firebase **App Check** (App Attest) before releasing.

Without step 2, sign-up works but items, history and the account flag can't be saved.

## No Mac?

You can build on a rented cloud Mac, or on GitHub Actions' `macos-latest`
runners with `xcodebuild -project ShelfLife-Firebase/ShelfLIFE.xcodeproj -scheme ShelfLIFE -destination 'generic/platform=iOS Simulator' build`.
