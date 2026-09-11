//
//  LoginView.swift
//  ShelfLIFE
//
//  Created by Mac-LAB on 9/11/26.
//

import SwiftUI

// MARK: - Login / Sign up
/// One screen that does both, switched by `isSigningUp`.
struct LoginView: View {
    @EnvironmentObject var auth: AuthService

    @State private var email = ""
    @State private var password = ""
    @State private var isSigningUp = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Logo
            ZStack {
                Circle()
                    .fill(AppColor.green.opacity(0.2))
                    .frame(width: 120, height: 120)
                Circle()
                    .fill(AppColor.orange)
                    .frame(width: 56, height: 56)
                Text("📷").font(.system(size: 24))
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 30)

            Text(isSigningUp ? "Create account" : "Welcome back")
                .font(.system(size: 30, weight: .heavy))
                .foregroundColor(.white)
                .padding(.bottom, 8)

            Text(isSigningUp
                 ? "Your items sync across your devices."
                 : "Sign in to reach your items.")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.7))
                .padding(.bottom, 26)

            // Fields
            TextField("", text: $email, prompt: fieldLabel("Email"))
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .foregroundColor(.white)
                .padding(15)
                .background(Color.white.opacity(0.1))
                .cornerRadius(14)
                .padding(.bottom, 10)

            SecureField("", text: $password, prompt: fieldLabel("Password"))
                .foregroundColor(.white)
                .padding(15)
                .background(Color.white.opacity(0.1))
                .cornerRadius(14)

            // Error message
            if !auth.errorMessage.isEmpty {
                Text(auth.errorMessage)
                    .font(.system(size: 13))
                    .foregroundColor(AppColor.red)
                    .padding(.top, 10)
            }

            // Forgot password
            if !isSigningUp {
                Button("Forgot password?") {
                    auth.resetPassword(email: email)
                }
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.7))
                .padding(.top, 12)
            }

            Spacer()

            // Main button
            Button {
                if isSigningUp {
                    auth.signUp(email: email, password: password)
                } else {
                    auth.signIn(email: email, password: password)
                }
            } label: {
                Group {
                    if auth.isWorking {
                        ProgressView().tint(.white)
                    } else {
                        Text(isSigningUp ? "Sign Up" : "Sign In")
                            .font(.system(size: 16, weight: .semibold))
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(AppColor.green)
                .cornerRadius(24)
            }
            .disabled(auth.isWorking)

            // Switch between the two modes
            Button {
                isSigningUp.toggle()
                auth.errorMessage = ""
            } label: {
                Text(isSigningUp
                     ? "Already have an account? Sign in"
                     : "New here? Create an account")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.7))
                    .frame(maxWidth: .infinity)
                    .padding(.top, 16)
            }
        }
        .padding(32)
        .padding(.top, 50)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColor.dark)
        .ignoresSafeArea()
    }

    private func fieldLabel(_ text: String) -> Text {
        Text(text).foregroundColor(.white.opacity(0.45))
    }
}

#Preview {
    LoginView().environmentObject(AuthService())
}
