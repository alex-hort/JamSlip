//
//  EditProfileView.swift
//  Splash Screen
//
//  Created by Alexis Horteales Espinosa on 15/01/26.
//
import SwiftUI
import PhotosUI
import FirebaseAuth

struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authVM: AuthViewModel
    @ObservedObject var profileVM: ProfileViewModel
    
    let user: User
    
    // Campos editables
    @State private var fullName: String = ""
    @State private var bio: String = ""
    
    // Para seleccionar imágenes
    @State private var showProfileImagePicker = false
    @State private var showBannerImagePicker = false
    @State private var showProfileActionSheet = false
    @State private var showBannerActionSheet = false
    
    // Estados
    @State private var tempProfileImage: UIImage?
    @State private var tempBannerImage: UIImage?
    @State private var removeProfileImage = false
    @State private var removeBannerImage = false
 
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 0) {
                        // Banner y foto de perfil
                        EditProfileHeader(
                            user: user,
                            tempProfileImage: $tempProfileImage,
                            tempBannerImage: $tempBannerImage,
                            removeProfileImage: $removeProfileImage,
                            removeBannerImage: $removeBannerImage,
                            showProfileActionSheet: $showProfileActionSheet,
                            showBannerActionSheet: $showBannerActionSheet
                        )
                        
                        Spacer().frame(height: 60)
                        
                        // Campos de edición
                        EditProfileFields(
                            fullName: $fullName,
                            bio: $bio
                        )
                        
                        
                        
                        Spacer().frame(height: 100)
                    }
                }
                
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                    .disabled(false)

                }
                
                ToolbarItem(placement: .principal) {
                    Text("Edit profile")
                        .font(.headline)
                        .foregroundColor(.white)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveProfileOptimistic()
                    }
                    .fontWeight(.bold)
                    .foregroundColor(hasChanges ? .white : .gray)
                  
                }
            }
            .photosPicker(isPresented: $showProfileImagePicker, selection: $profileVM.selectedProfileImage, matching: .images)
            .photosPicker(isPresented: $showBannerImagePicker, selection: $profileVM.selectedBannerImage, matching: .images)
            .onChange(of: profileVM.selectedProfileImage) { _, _ in
                Task {
                    await profileVM.loadProfileImage()
                    if let image = profileVM.profileImage {
                        tempProfileImage = image
                        removeProfileImage = false
                    }
                }
            }
            .onChange(of: profileVM.selectedBannerImage) { _, _ in
                Task {
                    await profileVM.loadBannerImage()
                    if let image = profileVM.bannerImage {
                        tempBannerImage = image
                        removeBannerImage = false
                    }
                }
            }
            .onAppear {
                fullName = user.fullName
                bio = user.bio ?? ""
            }
        
        }
        .confirmationDialog("Profile photo", isPresented: $showProfileActionSheet, titleVisibility: .visible) {
            Button("Photo library") {
                showProfileImagePicker = true
            }
            Button("Remove", role: .destructive) {
                tempProfileImage = nil
                removeProfileImage = true
            }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog("Banner photo", isPresented: $showBannerActionSheet, titleVisibility: .visible) {
            Button("Photo library") {
                showBannerImagePicker = true
            }
            Button("Remove", role: .destructive) {
                tempBannerImage = nil
                removeBannerImage = true
            }
            Button("Cancel", role: .cancel) {}
        }
        .interactiveDismissDisabled(false)

    }
    
    private var hasChanges: Bool {
        fullName != user.fullName ||
        bio != (user.bio ?? "") ||
        tempProfileImage != nil ||
        tempBannerImage != nil ||
        removeProfileImage ||
        removeBannerImage
    }
    
    // MARK: - Guardado Optimista (Instantáneo)
    private func saveProfileOptimistic() {
        // 1. Guardar imágenes temporales para el ProfileViewModel
        if let profileImg = tempProfileImage {
            profileVM.tempProfileImage = profileImg
        }
        if let bannerImg = tempBannerImage {
            profileVM.tempBannerImage = bannerImg
        }
        
        // 2. Guardar flags de eliminación
        profileVM.shouldRemoveProfile = removeProfileImage
        profileVM.shouldRemoveBanner = removeBannerImage
        
        // 3. Guardar datos de texto temporales
        profileVM.pendingFullName = fullName
        profileVM.pendingBio = bio.isEmpty ? nil : bio
        
        // 4. Cerrar inmediatamente (UI instantánea)
        dismiss()
        
        // 5. Subir en background
        Task.detached {
            await profileVM.saveAllChangesInBackground(for: user)
        }
    }
    
   
    
}
