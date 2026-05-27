//
//  ProfileViewModel.swift
//  Splash Screen
//
//  Created by Alexis Horteales Espinosa on 08/01/26.
//

import Foundation
import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import PhotosUI
import Combine

@MainActor
final class ProfileViewModel: ObservableObject {
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedProfileImage: PhotosPickerItem?
    @Published var selectedBannerImage: PhotosPickerItem?
    @Published var profileImage: UIImage?
    @Published var bannerImage: UIImage?
    
    // Imágenes temporales para mostrar inmediatamente
    @Published var tempProfileImage: UIImage?
    @Published var tempBannerImage: UIImage?
    
    // ✅ NUEVO: Usuario cargado con datos frescos
    @Published var loadedUser: User?
    @Published var isLoadingUser = false
    
    // Datos pendientes de guardar
    var pendingFullName: String?
    var pendingBio: String?
    var shouldRemoveProfile = false
    var shouldRemoveBanner = false
    
    private let firestore = Firestore.firestore()
    private let storage = Storage.storage()
    
    // MARK: - ✅ NUEVO: Cargar datos frescos del usuario desde Firebase
    func loadFreshUserData(userId: String) async {
        isLoadingUser = true
        
        do {
            let doc = try await firestore.collection("users").document(userId).getDocument()
            
            guard let data = doc.data() else {
                await MainActor.run {
                    isLoadingUser = false
                }
                return
            }
            
            var premiumExpiresAt: Date? = nil
            if let timestamp = data["premiumExpiresAt"] as? Timestamp {
                premiumExpiresAt = timestamp.dateValue()
            }
            
            var joinedDate: Date? = nil
            if let timestamp = data["joinedDate"] as? Timestamp {
                joinedDate = timestamp.dateValue()
            }
            
            let user = User(
                uid: userId,
                email: data["email"] as? String ?? "",
                fullName: data["fullName"] as? String ?? "",
                username: data["username"] as? String ?? "",
                bio: data["bio"] as? String,
                profileImageUrl: data["profileImageUrl"] as? String,
                bannerImageUrl: data["bannerImageUrl"] as? String,
                joinedDate: joinedDate,
                followingCount: data["followingCount"] as? Int ?? 0,
                followersCount: data["followersCount"] as? Int ?? 0,
                jamsCount: data["jamsCount"] as? Int ?? 0,
                isPremium: data["isPremium"] as? Bool,
                premiumExpiresAt: premiumExpiresAt,
                isInTrialPeriod: data["isInTrialPeriod"] as? Bool
            )
            
            await MainActor.run {
                self.loadedUser = user
                self.isLoadingUser = false
                
                print("✅ Usuario cargado desde Firebase:")
                print("   Nombre: \(user.fullName)")
                print("   Username: @\(user.username)")
                print("   ProfileImage: \(user.profileImageUrl ?? "nil")")
                print("   BannerImage: \(user.bannerImageUrl ?? "nil")")
                print("   Premium: \(user.isPremium)")
            }
        } catch {
            print("❌ Error cargando usuario: \(error)")
            await MainActor.run {
                isLoadingUser = false
            }
        }
    }
    
    // MARK: - Save All Changes in Background (Optimistic)
    func saveAllChangesInBackground(for user: User) async {
        // Ejecutar todo en paralelo para máxima velocidad
        await withTaskGroup(of: Void.self) { group in
            
            // 1. Guardar texto (nombre y bio) - muy rápido
            if let fullName = pendingFullName {
                group.addTask {
                    try? await self.updateProfile(
                        uid: user.uid,
                        fullName: fullName,
                        bio: self.pendingBio
                    )
                }
            }
            
            // 2. Subir foto de perfil si hay
            if let profileImg = tempProfileImage {
                group.addTask {
                    await self.uploadProfileImageBackground(profileImg, for: user)
                }
            } else if shouldRemoveProfile {
                group.addTask {
                    try? await self.removeProfileImage(for: user)
                }
            }
            
            // 3. Subir banner si hay
            if let bannerImg = tempBannerImage {
                group.addTask {
                    await self.uploadBannerImageBackground(bannerImg, for: user)
                }
            } else if shouldRemoveBanner {
                group.addTask {
                    try? await self.removeBannerImage(for: user)
                }
            }
        }
        
        // Limpiar datos temporales
        await MainActor.run {
            self.tempProfileImage = nil
            self.tempBannerImage = nil
            self.pendingFullName = nil
            self.pendingBio = nil
            self.shouldRemoveProfile = false
            self.shouldRemoveBanner = false
        }
    }
    
    // MARK: - Upload en Background (sin bloquear UI)
    private func uploadProfileImageBackground(_ image: UIImage, for user: User) async {
        do {
            let imageUrl = try await uploadImageCompressed(image, path: "profile_images/\(user.uid)")
            try await updateUserField(uid: user.uid, field: "profileImageUrl", value: imageUrl)
            
            // Limpiar cache viejo
            if let oldUrl = user.profileImageUrl {
                ImageCacheService.shared.removeFromCache(url: oldUrl)
            }
        } catch {
            print("⚠️ Error uploading profile image: \(error)")
        }
    }
    
    private func uploadBannerImageBackground(_ image: UIImage, for user: User) async {
        do {
            let imageUrl = try await uploadImageCompressed(image, path: "banner_images/\(user.uid)")
            try await updateUserField(uid: user.uid, field: "bannerImageUrl", value: imageUrl)
            
            // Limpiar cache viejo
            if let oldUrl = user.bannerImageUrl {
                ImageCacheService.shared.removeFromCache(url: oldUrl)
            }
        } catch {
            print("⚠️ Error uploading banner image: \(error)")
        }
    }
    
    // MARK: - Update Profile (Name & Bio)
    func updateProfile(uid: String, fullName: String, bio: String?) async throws {
        var data: [String: Any] = [
            "fullName": fullName
        ]
        
        if let bio = bio {
            data["bio"] = bio
        } else {
            data["bio"] = FieldValue.delete()
        }
        
        try await firestore
            .collection("users")
            .document(uid)
            .updateData(data)
    }
    
    // MARK: - Upload Profile Image
    func uploadProfileImage(for user: User) async {
        guard let image = profileImage else { return }
        isLoading = true
        
        do {
            let imageUrl = try await uploadImageCompressed(image, path: "profile_images/\(user.uid)")
            try await updateUserField(uid: user.uid, field: "profileImageUrl", value: imageUrl)
            
            if let oldUrl = user.profileImageUrl {
                ImageCacheService.shared.removeFromCache(url: oldUrl)
            }
        } catch {
            errorMessage = "Error subiendo imagen de perfil: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    // MARK: - Upload Banner Image
    func uploadBannerImage(for user: User) async {
        guard let image = bannerImage else { return }
        isLoading = true
        
        do {
            let imageUrl = try await uploadImageCompressed(image, path: "banner_images/\(user.uid)")
            try await updateUserField(uid: user.uid, field: "bannerImageUrl", value: imageUrl)
            
            if let oldUrl = user.bannerImageUrl {
                ImageCacheService.shared.removeFromCache(url: oldUrl)
            }
        } catch {
            errorMessage = "Error subiendo banner: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    // MARK: - Remove Profile Image
    func removeProfileImage(for user: User) async throws {
        let storageRef = storage.reference().child("profile_images/\(user.uid)")
        try? await storageRef.delete()
        
        try await firestore
            .collection("users")
            .document(user.uid)
            .updateData(["profileImageUrl": FieldValue.delete()])
        
        if let oldUrl = user.profileImageUrl {
            ImageCacheService.shared.removeFromCache(url: oldUrl)
        }
        
        await MainActor.run {
            profileImage = nil
        }
    }
    
    // MARK: - Remove Banner Image
    func removeBannerImage(for user: User) async throws {
        let storageRef = storage.reference().child("banner_images/\(user.uid)")
        try? await storageRef.delete()
        
        try await firestore
            .collection("users")
            .document(user.uid)
            .updateData(["bannerImageUrl": FieldValue.delete()])
        
        if let oldUrl = user.bannerImageUrl {
            ImageCacheService.shared.removeFromCache(url: oldUrl)
        }
        
        await MainActor.run {
            bannerImage = nil
        }
    }
    
    // MARK: - Upload Image Helper (Optimizado)
    private func uploadImageCompressed(_ image: UIImage, path: String) async throws -> String {
        // Redimensionar imagen para subida más rápida
        let maxSize: CGFloat = 1024
        let resizedImage = resizeImage(image, maxSize: maxSize)
        
        guard let imageData = resizedImage.jpegData(compressionQuality: 0.6) else {
            throw NSError(domain: "ImageError", code: 0, userInfo: [NSLocalizedDescriptionKey: "No se pudo comprimir la imagen"])
        }
        
        let storageRef = storage.reference().child(path)
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        let _ = try await storageRef.putDataAsync(imageData, metadata: metadata)
        let downloadUrl = try await storageRef.downloadURL()
        
        return downloadUrl.absoluteString
    }
    
    // MARK: - Resize Image
    private func resizeImage(_ image: UIImage, maxSize: CGFloat) -> UIImage {
        let size = image.size
        
        guard size.width > maxSize || size.height > maxSize else {
            return image
        }
        
        let ratio = min(maxSize / size.width, maxSize / size.height)
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return resizedImage ?? image
    }
    
    // MARK: - Update User Field
    private func updateUserField(uid: String, field: String, value: Any) async throws {
        try await firestore
            .collection("users")
            .document(uid)
            .updateData([field: value])
    }
    
    // MARK: - Load Image from Picker
    func loadProfileImage() async {
        guard let item = selectedProfileImage else { return }
        
        guard let data = try? await item.loadTransferable(type: Data.self) else { return }
        guard let uiImage = UIImage(data: data) else { return }
        
        profileImage = uiImage
    }
    
    func loadBannerImage() async {
        guard let item = selectedBannerImage else { return }
        
        guard let data = try? await item.loadTransferable(type: Data.self) else { return }
        guard let uiImage = UIImage(data: data) else { return }
        
        bannerImage = uiImage
    }
    
    // MARK: - Reset
    func reset() {
        selectedProfileImage = nil
        selectedBannerImage = nil
        profileImage = nil
        bannerImage = nil
        tempProfileImage = nil
        tempBannerImage = nil
        loadedUser = nil
        isLoadingUser = false
    }
}
