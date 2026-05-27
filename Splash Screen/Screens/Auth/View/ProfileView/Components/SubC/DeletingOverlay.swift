//
//  DeletingOverlay.swift
//  Splash Screen
//
//  Created by Alexis Horteales Espinosa on 31/01/26.
//

import SwiftUI
import FirebaseAuth

struct DeletingOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.8)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.5)
                
                Text("Deleting account...")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text("This may take a moment")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
        }
    }
}




extension View {
    func deleteAccountAlerts(
        showDeleteAccountAlert: Binding<Bool>,
        showDeleteConfirmation: Binding<Bool>,
        showPasswordPrompt: Binding<Bool>,
        deleteConfirmText: Binding<String>,
        deletePassword: Binding<String>,
        deleteError: Binding<String?>,
        isGoogleUser: Binding<Bool>,
        onDeleteWithPassword: @escaping () -> Void,
        onDeleteWithGoogle: @escaping () -> Void,
        onCheckGoogleUser: @escaping () -> Void
    ) -> some View {
        self
            // First Alert - Warning
            .alert("Delete Account?", isPresented: showDeleteAccountAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Continue", role: .destructive) {
                    onCheckGoogleUser()
                    showDeleteConfirmation.wrappedValue = true
                }
            } message: {
                Text("This action is permanent and cannot be undone. All your data including jams, likes, reposts, and profile information will be permanently deleted from JamSlip.")
            }
            // Second Alert - Type DELETE
            .alert("Confirm Deletion", isPresented: showDeleteConfirmation) {
                TextField("Type DELETE to confirm", text: deleteConfirmText)
                    .autocapitalization(.allCharacters)
                
                Button("Cancel", role: .cancel) {
                    deleteConfirmText.wrappedValue = ""
                }
                
                Button("Continue", role: .destructive) {
                    if deleteConfirmText.wrappedValue.uppercased() == "DELETE" {
                        deleteConfirmText.wrappedValue = ""
                        if isGoogleUser.wrappedValue {
                            onDeleteWithGoogle()
                        } else {
                            showPasswordPrompt.wrappedValue = true
                        }
                    }
                }
                .disabled(deleteConfirmText.wrappedValue.uppercased() != "DELETE")
            } message: {
                Text("Type DELETE to confirm permanent account removal.")
            }
            // Third Alert - Password (for email users)
            .alert("Enter Password", isPresented: showPasswordPrompt) {
                SecureField("Password", text: deletePassword)
                
                Button("Cancel", role: .cancel) {
                    deletePassword.wrappedValue = ""
                }
                
                Button("Delete Account", role: .destructive) {
                    onDeleteWithPassword()
                }
                .disabled(deletePassword.wrappedValue.isEmpty)
            } message: {
                Text("Enter your password to confirm account deletion.")
            }
            // Error Alert
            .alert("Error", isPresented: .constant(deleteError.wrappedValue != nil)) {
                Button("OK") {
                    deleteError.wrappedValue = nil
                }
            } message: {
                Text(deleteError.wrappedValue ?? "An error occurred")
            }
    }
}
