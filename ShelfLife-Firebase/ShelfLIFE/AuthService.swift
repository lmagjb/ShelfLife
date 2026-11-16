import SwiftUI
import Combine
import FirebaseAuth
import FirebaseCore

// MARK: - Auth
/// Handles signing up, signing in, and signing out.
/// Views watch `user` to know whether someone is logged in.
final class AuthService: ObservableObject {

    /// The signed-in user, or nil when nobody is signed in.
    @Published var user: User?

    /// Shown in red on the login screen when something goes wrong.
    @Published var errorMessage = ""

    /// True while a request is in flight.
    @Published var isWorking = false

    private var listener: AuthStateDidChangeListenerHandle?

    init() {
        // Normally AppDelegate has already done this. Xcode previews skip
        // the app delegate, so configure here too or the preview crashes.
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }

        // Firebase reports every sign-in change, including at launch when
        // it restores the previous session. That is what keeps the user
        // signed in between runs without any extra code.
        listener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            self?.user = user
        }
    }

    deinit {
        if let listener {
            Auth.auth().removeStateDidChangeListener(listener)
        }
    }

    var userID: String? { user?.uid }

    var email: String { user?.email ?? "" }

    var isSignedIn: Bool { user != nil }

    /// The name set in Profile → Edit name, or the part of the email
    /// before the @.
    var displayName: String {
        if let name = user?.displayName, !name.trimmingCharacters(in: .whitespaces).isEmpty {
            return name
        }
        return String(email.split(separator: "@").first ?? "Account")
    }

    /// Up to two letters for the avatar: "Juan Cruz" → "JC", "juan" → "JU".
    var initials: String {
        let words = displayName.split(separator: " ")
        if words.count >= 2 {
            return words.prefix(2).compactMap { $0.first }.map(String.init).joined().uppercased()
        }
        return String(displayName.prefix(2)).uppercased()
    }

    // MARK: Actions

    func signUp(email: String, password: String) {
        guard check(email: email, password: password) else { return }

        isWorking = true
        Auth.auth().createUser(withEmail: email, password: password) { [weak self] _, error in
            self?.isWorking = false
            self?.errorMessage = error.map(Self.readable) ?? ""
        }
    }

    func signIn(email: String, password: String) {
        guard check(email: email, password: password) else { return }

        isWorking = true
        Auth.auth().signIn(withEmail: email, password: password) { [weak self] _, error in
            self?.isWorking = false
            self?.errorMessage = error.map(Self.readable) ?? ""
        }
    }

    func signOut() {
        do {
            try Auth.auth().signOut()
            errorMessage = ""
        } catch {
            errorMessage = "Could not sign out. Try again."
        }
    }

    func resetPassword(email: String) {
        guard !email.isEmpty else {
            errorMessage = "Enter your email first."
            return
        }
        Auth.auth().sendPasswordReset(withEmail: email) { [weak self] error in
            self?.errorMessage = error == nil
                ? "Check your email for a reset link."
                : "Could not send the reset email."
        }
    }

    // MARK: Profile

    /// Saves a display name on the Firebase account. `completion` gets an
    /// error message, or nil when it worked.
    func updateDisplayName(_ name: String, completion: @escaping (String?) -> Void) {
        guard let user else { return }
        let change = user.createProfileChangeRequest()
        change.displayName = name.trimmingCharacters(in: .whitespaces)
        change.commitChanges { [weak self] error in
            if let error {
                completion(Self.readable(error))
                return
            }
            // Same User object with a new name, so tell the screens.
            self?.objectWillChange.send()
            self?.user = Auth.auth().currentUser
            completion(nil)
        }
    }

    /// Deletes the account for good. Firebase only allows it right after
    /// signing in, so the password is checked again first. Then
    /// `deleteData` removes the items and history, and finally the login
    /// itself is deleted, which signs the user out.
    func deleteAccount(password: String,
                       deleteData: @escaping (String, @escaping (Error?) -> Void) -> Void,
                       completion: @escaping (String?) -> Void) {
        guard let user, let email = user.email else {
            completion("No account is signed in.")
            return
        }
        isWorking = true
        let credential = EmailAuthProvider.credential(withEmail: email, password: password)

        user.reauthenticate(with: credential) { [weak self] _, error in
            if let error {
                self?.isWorking = false
                completion(Self.readable(error))
                return
            }
            deleteData(user.uid) { error in
                if let error {
                    self?.isWorking = false
                    completion("Couldn't delete your items: \(error.localizedDescription)")
                    return
                }
                user.delete { error in
                    self?.isWorking = false
                    if let error {
                        completion(Self.readable(error))
                        return
                    }
                    UserDefaults.standard.removeObject(forKey: "seeded-\(user.uid)")
                    completion(nil)
                }
            }
        }
    }

    // MARK: Helpers

    /// Catches the obvious problems before calling Firebase.
    private func check(email: String, password: String) -> Bool {
        if email.trimmingCharacters(in: .whitespaces).isEmpty {
            errorMessage = "Enter your email."
            return false
        }
        if !email.contains("@") {
            errorMessage = "That doesn't look like an email address."
            return false
        }
        if password.count < 6 {
            errorMessage = "Password must be at least 6 characters."
            return false
        }
        errorMessage = ""
        return true
    }

    /// Turns Firebase error codes into something a person can read.
    private static func readable(_ error: Error) -> String {
        switch AuthErrorCode(rawValue: (error as NSError).code) {
        case .emailAlreadyInUse: return "That email already has an account."
        case .invalidEmail:      return "That email address isn't valid."
        case .weakPassword:      return "Pick a stronger password."
        case .wrongPassword:     return "Wrong password."
        case .userNotFound:      return "No account found for that email."
        case .invalidCredential: return "Email or password is incorrect."
        case .networkError:      return "No internet connection."
        case .tooManyRequests:   return "Too many attempts. Wait a moment."
        default:                 return error.localizedDescription
        }
    }
}
