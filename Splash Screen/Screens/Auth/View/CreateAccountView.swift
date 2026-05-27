//
//  CreateAccountView.swift
//  Splash Screen
//
//  Created by Alexis Horteales Espinosa on 05/01/26.
//
import SwiftUI

struct CreateAccountView: View {

    // MARK: - State
    @State private var email = ""
    @State private var fullName = ""
    @State private var username = ""
    @State private var password = ""
    @State private var confirmPassword = ""

    @State private var showPassword = false
    @State private var showConfirmPassword = false

    @State private var isLoading = false
    @State private var usernameError: String?
    @State private var isCheckingUsername = false
    @State private var passwordFocused = false

    @EnvironmentObject var authVM: AuthViewModel

    // MARK: - Email Validation
    // Acepta: @gmail.com @hotmail.com @outlook.com @icloud.com @yahoo.com
    // y cualquier dominio con TLD válido (al menos 2 letras)
    private var isValidEmail: Bool {
        let pattern = #"^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$"#
        return email.range(of: pattern, options: .regularExpression) != nil
    }

    private var emailError: String? {
        guard !email.isEmpty else { return nil }
        if !email.contains("@") { return "Must include @" }
        let parts = email.split(separator: "@")
        if parts.count != 2 { return "Invalid email format" }
        let domain = String(parts[1])
        if !domain.contains(".") { return "Invalid domain" }
        let tld = domain.split(separator: ".").last ?? ""
        if tld.count < 2 { return "Invalid domain extension" }
        if !isValidEmail { return "Enter a valid email" }
        return nil
    }

    private var isValidUsername: Bool {
        !username.isEmpty && username.count <= 10
    }

    // MARK: - Password Requirements
    private var hasMinLength: Bool      { password.count >= 8 }
    private var hasUppercase: Bool      { password.range(of: "[A-Z]", options: .regularExpression) != nil }
    private var hasLowercase: Bool      { password.range(of: "[a-z]", options: .regularExpression) != nil }
    private var hasNumber: Bool         { password.range(of: "[0-9]", options: .regularExpression) != nil }
    private var hasSpecialChar: Bool    { password.range(of: "[!@#$%^&*()_+\\-=\\[\\]{}|;':\",./<>?]", options: .regularExpression) != nil }

    private var isValidPassword: Bool {
        hasMinLength && hasUppercase && hasLowercase && hasNumber && hasSpecialChar
    }

    private var passwordStrength: PasswordStrength {
        let met = [hasMinLength, hasUppercase, hasLowercase, hasNumber, hasSpecialChar].filter { $0 }.count
        switch met {
        case 0...2: return .weak
        case 3...4: return .medium
        default:    return .strong
        }
    }

    private var passwordsMatch: Bool {
        password == confirmPassword && !password.isEmpty
    }

    private var canCreateAccount: Bool {
        isValidEmail &&
        !fullName.isEmpty &&
        isValidUsername &&
        isValidPassword &&
        passwordsMatch &&
        usernameError == nil &&
        !isCheckingUsername
    }

    // MARK: - Body
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 28) {

                        // Header
                        VStack(spacing: 8) {
                            Text("Create your account")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)

                            Text("This will only take a minute")
                                .font(.subheadline)
                                .foregroundStyle(.gray)
                        }
                        .padding(.top, 24)

                        // Form
                        VStack(spacing: 14) {

                            // EMAIL
                            VStack(alignment: .leading, spacing: 4) {
                                AuthInputField(
                                    placeholder: "Email",
                                    systemImage: "envelope.fill",
                                    text: $email,
                                    trailingIcon: email.isEmpty ? nil :
                                        (isValidEmail ? "checkmark.circle.fill" : "xmark.circle.fill"),
                                    trailingColor: isValidEmail ? .green : .red
                                )
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)

                                if let err = emailError {
                                    Text(err)
                                        .font(.caption)
                                        .foregroundColor(.red.opacity(0.8))
                                        .padding(.leading, 4)
                                }
                            }

                            // FULL NAME
                            AuthInputField(
                                placeholder: "Full name",
                                systemImage: "person.fill",
                                text: $fullName
                            )

                            // USERNAME
                            VStack(alignment: .leading, spacing: 4) {
                                AuthInputField(
                                    placeholder: "@username (max 10)",
                                    systemImage: "at",
                                    text: $username,
                                    trailingIcon: username.isEmpty ? nil :
                                        (usernameError != nil ? "xmark.circle.fill" : "checkmark.circle.fill"),
                                    trailingColor: usernameError != nil ? .red : .green,
                                    isLoading: isCheckingUsername
                                )
                                .onChange(of: username) { _, newValue in
                                    if newValue.count > 10 {
                                        username = String(newValue.prefix(10))
                                    }
                                    usernameError = nil
                                    checkUsernameAvailability()
                                }

                                if let err = usernameError {
                                    Text(err)
                                        .font(.caption)
                                        .foregroundColor(.red.opacity(0.8))
                                        .padding(.leading, 4)
                                }
                            }

                            // PASSWORD
                            VStack(alignment: .leading, spacing: 8) {
                                AuthInputField(
                                    placeholder: "Password",
                                    systemImage: "lock.fill",
                                    isSecure: true,
                                    text: $password,
                                    showEye: true,
                                    trailingIcon: password.isEmpty ? nil :
                                        (isValidPassword ? "checkmark.circle.fill" : "xmark.circle.fill"),
                                    trailingColor: isValidPassword ? .green : .red
                                )
                                .onChange(of: password) { _, _ in
                                    passwordFocused = true
                                }

                                // Barra de fuerza
                                if !password.isEmpty {
                                    PasswordStrengthBar(strength: passwordStrength)
                                }

                                // Requisitos
                                if !password.isEmpty && !isValidPassword {
                                    VStack(alignment: .leading, spacing: 4) {
                                        PasswordRequirement(text: "At least 8 characters", isMet: hasMinLength)
                                        PasswordRequirement(text: "One uppercase letter (A-Z)", isMet: hasUppercase)
                                        PasswordRequirement(text: "One lowercase letter (a-z)", isMet: hasLowercase)
                                        PasswordRequirement(text: "One number (0-9)", isMet: hasNumber)
                                        PasswordRequirement(text: "One special character (!@#$%...)", isMet: hasSpecialChar)
                                    }
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 6)
                                    .background(Color.white.opacity(0.04))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                            }

                            // CONFIRM PASSWORD
                            AuthInputField(
                                placeholder: "Confirm password",
                                systemImage: "lock.rotation",
                                isSecure: true,
                                text: $confirmPassword,
                                showEye: true,
                                trailingIcon: confirmPassword.isEmpty ? nil :
                                    (passwordsMatch ? "checkmark.circle.fill" : "xmark.circle.fill"),
                                trailingColor: passwordsMatch ? .green : .red
                            )
                        }
                        .padding(22)
                        .background(
                            RoundedRectangle(cornerRadius: 28)
                                .fill(Color.white.opacity(0.03))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 28)
                                        .stroke(Color.white.opacity(0.08))
                                )
                        )

                        Spacer(minLength: 120)
                    }
                    .padding(.horizontal)
                }

                // CTA
                VStack {
                    Spacer()

                    Button {
                        createAccount()
                    } label: {
                        HStack {
                            if isLoading {
                                ProgressView().tint(.black)
                            }
                            Text(isLoading ? "Creating..." : "Create account")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(CapsuleButtonStyle())
                    .disabled(!canCreateAccount || isLoading)
                    .opacity(canCreateAccount ? 1 : 0.6)
                    .padding()
                    .background(Color.black)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Sign up")
                        .font(.headline)
                        .foregroundStyle(.white)
                }
            }
            .toolbarBackground(.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    // MARK: - Functions

    private func checkUsernameAvailability() {
        guard !username.isEmpty else {
            usernameError = nil
            return
        }

        isCheckingUsername = true

        Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            let currentUsername = username

            do {
                let exists = try await authVM.usernameExists(currentUsername)

                await MainActor.run {
                    if username == currentUsername {
                        isCheckingUsername = false
                        usernameError = exists ? "Username already taken" : nil
                    }
                }
            } catch {
                await MainActor.run { isCheckingUsername = false }
            }
        }
    }

    private func createAccount() {
        isLoading = true

        Task {
            await authVM.createUser(
                email: email,
                fullname: fullName,
                username: username,
                password: password
            )
            await MainActor.run { isLoading = false }
        }
    }
}

// MARK: - Password Strength Enum
enum PasswordStrength {
    case weak, medium, strong

    var label: String {
        switch self {
        case .weak:   return "Weak"
        case .medium: return "Medium"
        case .strong: return "Strong"
        }
    }

    var color: Color {
        switch self {
        case .weak:   return .red
        case .medium: return .orange
        case .strong: return .green
        }
    }

    var filledBars: Int {
        switch self {
        case .weak:   return 1
        case .medium: return 2
        case .strong: return 3
        }
    }
}

// MARK: - Password Strength Bar
struct PasswordStrengthBar: View {
    let strength: PasswordStrength

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<3) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(index < strength.filledBars ? strength.color : Color.white.opacity(0.15))
                    .frame(height: 4)
            }

            Text(strength.label)
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundColor(strength.color)
        }
        .animation(.easeInOut(duration: 0.2), value: strength.filledBars)
    }
}

// MARK: - Password Requirement Row
struct PasswordRequirement: View {
    let text: String
    let isMet: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: isMet ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 11))
                .foregroundColor(isMet ? .green : .gray.opacity(0.6))

            Text(text)
                .font(.caption)
                .foregroundColor(isMet ? .white.opacity(0.8) : .gray.opacity(0.6))
        }
        .animation(.easeInOut(duration: 0.15), value: isMet)
    }
}

