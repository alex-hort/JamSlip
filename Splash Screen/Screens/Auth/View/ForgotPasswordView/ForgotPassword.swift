//
//  ForgotPassword.swift
//  Splash Screen
//
//  Created by Alexis Horteales Espinosa on 05/01/26.
//

import SwiftUI

struct ForgotPassword: View {
    @StateObject private var viewModel = PasswordResetViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {

            Button {
                dismiss()
            } label: {
                Image(systemName: "arrow.left")
                    .font(.title2)
                    .foregroundStyle(.gray)
            }

            Text("Forgot Password?")
                .font(.largeTitle)
                .fontWeight(.heavy)
                

            Text("Please enter your Email ID so that we can send the reset link.")
                .font(.caption)
                .foregroundStyle(.gray)

            VStack(spacing: 25) {

                CustomTF(sfIcon: "at", hint: "Email", value: $viewModel.email)

                GradientButton(title: "Send Link", icon: "arrow.right") {
                    Task {
                        let success = await viewModel.sendOTPCode()
                        if success {
                            // Esperar un momento para que el usuario vea el mensaje
                            try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 segundos
                            dismiss()
                        }
                    }
                }
                .clipShape(Capsule())
                .disabled(viewModel.isLoading)
                .opacity(viewModel.isLoading ? 0.6 : 1.0)
                
                if viewModel.isLoading {
                    ProgressView()
                        .tint(.white)
                }
            }
            .padding(.top, 20)
        }
        .padding()
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage)
        }
        .alert("Check your email", isPresented: $viewModel.showSuccess) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text(viewModel.successMessage)
        }
    }
}
