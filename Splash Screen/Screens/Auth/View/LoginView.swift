//
//  LoginView.swift
//  Splash Screen
//
//  Created by Alexis Horteales Espinosa on 05/01/26.
//

import SwiftUI
import AuthenticationServices

struct LoginView: View {
    
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var showResetView: Bool = false
    @State private var showForgotPasswordView: Bool = false
    @State private var isLoading: Bool = false
    @State private var showTerms: Bool = false
    @State private var showPrivacy: Bool = false
    
    @EnvironmentObject var authVM: AuthViewModel
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Logo
                        logo
                            .padding(.top, 40)
                        
                        // Title
                        titleView
                            .padding(.bottom, 10)
                        
                        Spacer()
                        
                        // Input Fields
                        VStack(spacing: 14) {

                            ElegantInputField(
                                placeholder: "Email or Username",
                                systemImage: "person.crop.circle",
                                isSecure: false,
                                text: $username
                            )
                            .disabled(isLoading)
                            
                            ElegantInputField(
                                placeholder: "Password",
                                systemImage: "lock.fill",
                                isSecure: true,
                                text: $password
                            )
                            .disabled(isLoading)
                        }
                        .padding(18)
                        .background(
                            RoundedRectangle(cornerRadius: 26)
                                .fill(Color.white.opacity(0.03))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 26)
                                        .stroke(Color.white.opacity(0.08))
                                )
                        )

                        
                        Spacer()
                        
                        // Login Button
                        loginButton
                            .padding(.top, 8)
                        
                        // Forgot Password
                        forgotButton
                            .padding(.top, -6)
                        
                        // Divider
                        HStack(spacing: 16) {
                            line
                            Text("or")
                                .fontWeight(.regular)
                                .foregroundStyle(.gray)
                            line
                        }
                        .padding(.vertical, 6)
                        .padding(.top)
                        
                        // Social Sign In Buttons
                        VStack(spacing: 12) {
                            // Google Sign In
                            googleButton
                                .disabled(isLoading)
                                .opacity(isLoading ? 0.6 : 1)
                            
                            // Apple Sign In
                            appleButton
                                .disabled(isLoading)
                                .opacity(isLoading ? 0.6 : 1)
                        }
                        
                        // Sign Up Footer
                        signUpFooter
                            .padding(.top, 20)
                            .disabled(isLoading)
                        
                        // Terms & Privacy
                        termsAndPrivacy
                            .padding(.top, 16)
                            .padding(.bottom, 30)
                    }
                    .padding(.horizontal)
                }
            }
            .sheet(isPresented: $showTerms) {
                TermsOfServiceView()
            }
            .sheet(isPresented: $showPrivacy) {
                PrivacyPolicyView()
            }
        }
    }
    
    // MARK: - Subviews
    
    private var logo: some View {
        Image(.logo)
            .resizable()
            .scaledToFit()
            .frame(width: 130)
            .accessibilityLabel("App Logo")
    }
    
    private var titleView: some View {
        Text("Let's Connect With Y'All")
            .font(.title2)
            .fontWeight(.semibold)
            .foregroundStyle(.white)
            .opacity(0.9)
            .multilineTextAlignment(.center)
    }
    
    private var forgotButton: some View {
        Button {
            showForgotPasswordView.toggle()
        } label: {
            Text("Forgot Password?")
                .foregroundStyle(.gray)
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .disabled(isLoading)
        .sheet(isPresented: $showForgotPasswordView) {
            ForgotPassword()
                .presentationDetents([.height(300)])
                .presentationCornerRadius(30)
        }
    }
    
    // MARK: Login Button with Progress
    private var loginButton: some View {
        Button {
            startLogin()
        } label: {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.9)
                        .tint(.black)
                }
                Text(isLoading ? "Signing in..." : "Login")
            }
        }
        .buttonStyle(CapsuleButtonStyle())
        .disabled(
            isLoading ||
            username.isEmpty ||
            password.isEmpty
        )
        .opacity(
            (isLoading || username.isEmpty || password.isEmpty) ? 0.6 : 1
        )
    }
    
    private var googleButton: some View {
        Button {
            guard !isLoading else { return }
            Task {
                await authVM.signInWithGoogle()
            }
        } label: {
            HStack {
                Image(.googleL)
                    .resizable()
                    .frame(width: 15, height: 15)
                Text("Continue with Google")
                    .fontWeight(.medium)
            }
        }
        .buttonStyle(CapsuleButtonStyle(bgColor: .white, textColor: .black))
    }
    
    private var appleButton: some View {
        Button {
            guard !isLoading else { return }
            Task {
                await authVM.signInWithApple()
            }
        } label: {
            HStack {
                Image(systemName: "apple.logo")
                    .font(.system(size: 16, weight: .medium))
                Text("Continue with Apple")
                    .fontWeight(.medium)
            }
        }
        .buttonStyle(CapsuleButtonStyle(bgColor: .white, textColor: .black))
    }
    
    private var signUpFooter: some View {
        NavigationLink {
            CreateAccountView()
        } label: {
            HStack(spacing: 4) {
                Text("Don't have an account?")
                    .foregroundStyle(.white)
                Text("Sign Up")
                    .foregroundStyle(.white)
                    .fontWeight(.semibold)
            }
            .font(.subheadline)
        }
    }
    
    // MARK: - Terms & Privacy
    private var termsAndPrivacy: some View {
        VStack(spacing: 4) {
            Text("By continuing, you agree to JamSlip's")
                .font(.caption)
                .foregroundStyle(.gray)
            
            HStack(spacing: 4) {
                Button {
                    showTerms = true
                } label: {
                    Text("Terms of Service")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                        .underline()
                }
                
                Text("&")
                    .font(.caption)
                    .foregroundStyle(.gray)
                
                Button {
                    showPrivacy = true
                } label: {
                    Text("Privacy Policy")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                        .underline()
                }
            }
        }
    }
    
    private var line: some View {
        Rectangle()
            .fill(Color.white.opacity(0.2))
            .frame(height: 1)
            .frame(maxWidth: .infinity)
    }
    
    // MARK: - Login Handler
    private func startLogin() {
        guard !isLoading else { return }
        isLoading = true
        
        Task {
            await authVM.signIn(emailOrUsername: username, password: password)
            isLoading = false
        }
    }
}






