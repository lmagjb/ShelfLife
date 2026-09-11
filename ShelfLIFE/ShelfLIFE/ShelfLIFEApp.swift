//
//  AuthService.swift
//  ShelfLIFE
//
//  Created by Mac-LAB on 9/7/26.
//


import SwiftUI
import FirebaseCore


class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()
        return true
    }
}

// App start
@main
struct ShelfLIFEApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    @StateObject private var data = AppData()
    @StateObject private var auth = AuthService()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(data)
                .environmentObject(auth)
        }
    }
}

struct RootView: View {
    @EnvironmentObject var data: AppData
    @EnvironmentObject var auth: AuthService

    var body: some View {
        Group {
            if auth.user == nil {
                LoginView()
            } else if !data.hasStarted {
                OnboardingView()
            } else {
                MainTabs()
            }
        }
        .onChange(of: auth.user) { _, user in
            if let user {
                data.connect(userID: user.uid)
            } else {
                data.disconnect()
            }
        }
        .onAppear {
            // Handles a session restored from a previous launch.
            if let user = auth.user {
                data.connect(userID: user.uid)
            }
        }
    }
}   

// The three tabs
struct MainTabs: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Home", systemImage: "house.fill") }

            VaultView()
                .tabItem { Label("Vault", systemImage: "archivebox.fill") }

            InsightsView()
                .tabItem { Label("Insights", systemImage: "chart.bar.fill") }
        }
        .accentColor(AppColor.green)
    }
}

// Welcome screen
struct OnboardingView: View {
    @EnvironmentObject var data: AppData

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Three circles with a camera in the middle
            ZStack {
                Circle()
                    .fill(AppColor.green.opacity(0.2))
                    .frame(width: 160, height: 160)
                Circle()
                    .fill(AppColor.brown.opacity(0.3))
                    .frame(width: 112, height: 112)
                Circle()
                    .fill(AppColor.orange)
                    .frame(width: 64, height: 64)
                Text("📷").font(.system(size: 28))
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 40)

            Text("ShelfLife")
                .font(.system(size: 38, weight: .heavy))
                .foregroundColor(.white)
                .padding(.bottom, 12)

            Text("Everything you own has a shelf life.")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white.opacity(0.7))
                .padding(.bottom, 10)

            Text("Track expiry dates, return windows, and warranties in one place.")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.7))

            Spacer()

            FilledButton(title: "Get Started", color: AppColor.green) {
                data.start()
            }
        }
        .padding(32)
        .padding(.top, 60)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColor.dark)
        .ignoresSafeArea()
    }
}

#Preview {
    RootView().environmentObject(AppData())
}
