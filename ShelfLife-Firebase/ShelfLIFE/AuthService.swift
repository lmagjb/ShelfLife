import SwiftUI
import Combine
import FirebaseAuth

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
