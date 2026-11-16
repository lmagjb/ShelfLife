import SwiftUI
import FirebaseCore
import UserNotifications

// MARK: - Launch setup
/// Firebase has to be configured the moment the app launches, before any
/// Auth or Firestore call runs. SwiftUI has no launch hook of its own, so
/// a small app delegate does it.
/// It also lets reminders show as a banner while the app is open; by
/// default iOS hides notifications for the app you're using.
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()
        UNUserNotificationCenter.current().delegate = self
        ReminderManager.shared.registerActions()
        return true
    }

    /// A tap on a reminder's "Mark used" or "+3 days" button. The store
    /// applies it once the item has loaded.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        ReminderManager.shared.handle(actionIdentifier: response.actionIdentifier,
                                      userInfo: response.notification.request.content.userInfo)
        NotificationCenter.default.post(name: .reminderActionReceived, object: nil)
        completionHandler()
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler:
                                    @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list, .sound])
    }
}

@main
struct ShelfLifeApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    @StateObject private var store = ShelfLifeStore()
    @StateObject private var auth = AuthService()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(auth)
        }
    }
}

extension Notification.Name {
    static let reminderActionReceived = Notification.Name("reminderActionReceived")
}

// MARK: - Decides which screen to show
/// Signed out shows the login screen. Signing in starts the Firestore
/// listener; signing out stops it and clears the local copy.
struct RootView: View {
    @EnvironmentObject var store: ShelfLifeStore
    @EnvironmentObject var auth: AuthService

    /// "system", "light" or "dark", chosen in Settings → Appearance.
    @AppStorage("appearance") private var appearance = "system"

    private var colorScheme: ColorScheme? {
        switch appearance {
        case "light": return .light
        case "dark":  return .dark
        default:      return nil   // follow the iPhone's setting
        }
    }

    var body: some View {
        ZStack {
            // The aurora sits under everything, so every frosted panel
            // in the app has colour to refract.
            AuroraBackground(animated: !auth.isSignedIn)

            if auth.isSignedIn {
                MainTabView()
                    .transition(.opacity)
            } else {
                LoginView()
                    .transition(.opacity)
            }
        }
        .preferredColorScheme(colorScheme)
        .animation(.easeInOut(duration: 0.35), value: auth.isSignedIn)
        .onChange(of: auth.user) { _, user in
            if let user {
                store.connect(userID: user.uid)
            } else {
                store.disconnect()
            }
        }
        // A reminder button tapped while the app was already running.
        .onReceive(NotificationCenter.default.publisher(for: .reminderActionReceived)) { _ in
            store.applyNotificationActions()
        }
        .onAppear {
            // Catches a session restored from a previous launch.
            if let user = auth.user {
                store.connect(userID: user.uid)
            }
        }
    }
}
