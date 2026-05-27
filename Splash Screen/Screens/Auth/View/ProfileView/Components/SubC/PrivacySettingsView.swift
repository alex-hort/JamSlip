//
//  PrivacySettingsView.swift
//  Splash Screen
//
//  Created by Alexis Horteales Espinosa on 12/02/26.
//
import SwiftUI
import FirebaseAuth

// MARK: - Privacy Settings View
struct PrivacySettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authVM: AuthViewModel
    
    // Delete Account States
    @State private var showDeleteAccountAlert = false
    @State private var showDeleteConfirmation = false
    @State private var showPasswordPrompt = false
    @State private var deletePassword = ""
    @State private var deleteConfirmText = ""
    @State private var isDeleting = false
    @State private var deleteError: String?
    @State private var isGoogleUser = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Data & Privacy
                        VStack(spacing: 14) {
                            sectionHeader("Data & Privacy")
                            
                            VStack(spacing: 1) {
                                actionRow(
                                    title: "Delete Account",
                                    subtitle: "Permanently delete your account",
                                    destructive: true
                                ) {
                                    checkGoogleUser()
                                    showDeleteAccountAlert = true
                                }
                            }
                            .background(
                                RoundedRectangle(cornerRadius: 18)
                                    .fill(Color.white.opacity(0.05))
                            )
                        }
                        
                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 20)
                }
                
                // ✅ Loading overlay (usando tu componente existente)
                if isDeleting {
                    DeletingOverlay()
                }
            }
            .navigationTitle("Privacy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .disabled(isDeleting)
                }
            }
            // ✅ Usando tu extension existente
            .deleteAccountAlerts(
                showDeleteAccountAlert: $showDeleteAccountAlert,
                showDeleteConfirmation: $showDeleteConfirmation,
                showPasswordPrompt: $showPasswordPrompt,
                deleteConfirmText: $deleteConfirmText,
                deletePassword: $deletePassword,
                deleteError: $deleteError,
                isGoogleUser: $isGoogleUser,
                onDeleteWithPassword: performDeleteWithPassword,
                onDeleteWithGoogle: performDeleteWithGoogle,
                onCheckGoogleUser: checkGoogleUser
            )
            .interactiveDismissDisabled(isDeleting)
        }
    }
    
    // MARK: - Components
    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title.uppercased())
                .font(.system(size: 13, weight: .semibold))
                .tracking(0.6)
                .foregroundColor(.gray)
            Spacer()
        }
        .padding(.horizontal, 4)
    }
    
    private func actionRow(
        title: String,
        subtitle: String,
        destructive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        
        
        Button(action: action) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 17))
                        .foregroundColor(destructive ? .red : .white)
                    
                    Text(subtitle)
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
    }
    
    // MARK: - ✅ DELETE ACCOUNT LOGIC
    
    private func checkGoogleUser() {
        if let providerData = Auth.auth().currentUser?.providerData {
            isGoogleUser = providerData.contains { $0.providerID == "google.com" }
        }
    }
    
    private func performDeleteWithPassword() {
        let password = deletePassword
        deletePassword = ""
        isDeleting = true
        
        Task {
            do {
                try await authVM.deleteAccountWithReauth(password: password)
                // ✅ Si llega aquí, la cuenta fue eliminada exitosamente
                // El AuthViewModel ya maneja el cierre de sesión
            } catch {
                await MainActor.run {
                    isDeleting = false
                    deleteError = error.localizedDescription
                }
            }
        }
    }
    
    private func performDeleteWithGoogle() {
        isDeleting = true
        
        Task {
            do {
                try await authVM.deleteAccountWithGoogleReauth()
                // ✅ Si llega aquí, la cuenta fue eliminada exitosamente
            } catch {
                await MainActor.run {
                    isDeleting = false
                    deleteError = error.localizedDescription
                }
            }
        }
    }
}
