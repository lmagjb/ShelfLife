import SwiftUI

// MARK: - Login / Sign up
/// One frosted panel floating on the animated aurora. `isSigningUp`
/// flips the same screen between the two modes.
struct LoginView: View {
    @EnvironmentObject var auth: AuthService

    @State private var email = ""
    @State private var password = ""
    @State private var isSigningUp = false
    @FocusState private var focusedField: Field?

    private enum Field { case email, password }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                logo
                    .padding(.top, 50)

                VStack(spacing: 8) {
                    Text("ShelfLife")
                        .font(.system(size: 34, weight: .bold, design: .rounded))

                    Text(isSigningUp
                         ? "Create an account to sync your items."
                         : "Everything you own has a shelf life.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 22)

                card
                    .padding(.horizontal, 22)
                    .padding(.top, 30)

                switchModeButton
                    .padding(.top, 20)
                    .padding(.bottom, 40)
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: Logo

    private var logo: some View {
        ZStack {
            Circle()
                .fill(AppTheme.sage.opacity(0.10))
                .frame(width: 148, height: 148)

            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: 104, height: 104)
                .overlay {
                    Circle().strokeBorder(Color.white.opacity(0.4), lineWidth: 1)
                }
                .shadow(color: AppTheme.sage.opacity(0.25), radius: 20, y: 10)

            Image(systemName: "viewfinder")
                .font(.system(size: 38, weight: .light))
                .foregroundStyle(
                    LinearGradient(colors: [AppTheme.sage, AppTheme.teal],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                )
        }
    }

    // MARK: Glass form panel

    private var card: some View {
        VStack(spacing: 14) {
            field(icon: "envelope", placeholder: "Email", text: $email,
                  isFocused: focusedField == .email)
                .focused($focusedField, equals: .email)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textContentType(.emailAddress)

            secureField(icon: "lock", placeholder: "Password",
                        isFocused: focusedField == .password)
                .focused($focusedField, equals: .password)

            if !auth.errorMessage.isEmpty {
                HStack(alignment: .top, spacing: 7) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.caption)
                    Text(auth.errorMessage)
                        .font(.footnote)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .foregroundStyle(AppTheme.danger)
                .padding(.top, 2)
            }

            if !isSigningUp {
                HStack {
                    Spacer()
                    Button("Forgot password?") {
                        auth.resetPassword(email: email)
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
            }

            Button {
                focusedField = nil
                if isSigningUp {
                    auth.signUp(email: email, password: password)
                } else {
                    auth.signIn(email: email, password: password)
                }
            } label: {
                if auth.isWorking {
                    ProgressView().tint(.white)
                } else {
                    Text(isSigningUp ? "Create Account" : "Sign In")
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(auth.isWorking)
            .padding(.top, 4)
        }
        .glassCard(cornerRadius: 28, padding: 20)
    }

    // MARK: Fields
    /// Fields are inset wells — a darker pane inside the panel — so they
    /// read as carved into the glass rather than stacked on top of it.

    private func field(icon: String, placeholder: String,
                       text: Binding<String>, isFocused: Bool) -> some View {
        HStack(spacing: 11) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(isFocused ? AppTheme.sage : .secondary)
                .frame(width: 18)

            TextField(placeholder, text: text)
                .font(.subheadline)
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 14)
        .background(wellBackground(isFocused: isFocused))
    }

    private func secureField(icon: String, placeholder: String,
                             isFocused: Bool) -> some View {
        HStack(spacing: 11) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(isFocused ? AppTheme.sage : .secondary)
                .frame(width: 18)

            SecureField(placeholder, text: $password)
                .font(.subheadline)
                .textContentType(isSigningUp ? .newPassword : .password)
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 14)
        .background(wellBackground(isFocused: isFocused))
    }

    @ViewBuilder
    private func wellBackground(isFocused: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        ZStack {
            shape.fill(Color.primary.opacity(0.05))
            shape.strokeBorder(
                isFocused ? AppTheme.sage.opacity(0.55) : Color.white.opacity(0.22),
                lineWidth: isFocused ? 1.5 : 1
            )
        }
        .animation(.easeOut(duration: 0.18), value: isFocused)
    }

    // MARK: Mode switch

    private var switchModeButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                isSigningUp.toggle()
                auth.errorMessage = ""
            }
        } label: {
            HStack(spacing: 4) {
                Text(isSigningUp ? "Already have an account?" : "New here?")
                    .foregroundStyle(.secondary)
                Text(isSigningUp ? "Sign in" : "Create an account")
                    .fontWeight(.semibold)
                    .foregroundStyle(AppTheme.sage)
            }
            .font(.subheadline)
        }
    }
}

#Preview {
    ZStack {
        AuroraBackground(animated: true)
        LoginView().environmentObject(AuthService())
    }
}
