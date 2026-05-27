//
//  ProfileTopSection.swift
//  Splash Screen
//
//  Created by Alexis Horteales Espinosa on 08/01/26.
//
import SwiftUI
import PhotosUI

struct ProfileTopSection: View {
    
    // MARK: - PROPERTIES
    let user: User
    @ObservedObject var profileVM: ProfileViewModel
    @EnvironmentObject var authVM: AuthViewModel
    var profileImage: UIImage?
    var onProfileUpdated: (() -> Void)? = nil
    
    @State private var showEditProfile = false
    @State private var showSignOutAlert = false
    @State private var isFollowLoading = false
    
    @StateObject private var followService = FollowService.shared
    
    private var isOwnProfile: Bool {
        followService.currentUserId == user.uid
    }
    
    // Imagen a mostrar (temporal o del servidor)
    private var displayProfileImage: UIImage? {
        profileVM.tempProfileImage ?? profileImage
    }
    
    var body: some View {
        HStack(alignment: .top) {
            // Foto de perfil
            ZStack(alignment: .bottomTrailing) {
                Group {
                    if let tempImg = profileVM.tempProfileImage {
                        // Mostrar imagen temporal inmediatamente
                        Image(uiImage: tempImg)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else if let profileImage = profileImage {
                        Image(uiImage: profileImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else if !profileVM.shouldRemoveProfile, let profileUrl = user.profileImageUrl, !profileUrl.isEmpty {
                        AsyncImage(url: URL(string: profileUrl)) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            default:
                                Circle()
                                    .fill(LinearGradient(
                                        colors: [.purple.opacity(0.5), .blue.opacity(0.5)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ))
                                    .overlay {
                                        ProgressView()
                                            .tint(.white)
                                            .scaleEffect(0.7)
                                    }
                            }
                        }
                    } else {
                        Circle()
                            .fill(LinearGradient(
                                colors: [.purple.opacity(0.5), .blue.opacity(0.5)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .overlay {
                                Image(systemName: "person.fill")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 30, height: 30)
                                    .foregroundColor(.white.opacity(0.7))
                            }
                    }
                }
                .frame(width: 75, height: 75)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.black, lineWidth: 4))
            }
            .offset(y: -40)
            
            Spacer()
            
            HStack(spacing: 8) {
                if isOwnProfile {
                    // Botón Edit profile
                    Button {
                        showEditProfile = true
                    } label: {
                        Text("Edit profile")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.white.opacity(0.4), lineWidth: 1)
                            )
                    }
                    
//                    // Botón cerrar sesión
//                    Button {
//                        showSignOutAlert = true
//                    } label: {
//                        Image(systemName: "rectangle.portrait.and.arrow.right")
//                            .foregroundColor(.white)
//                            .frame(width: 32, height: 32)
//                            .overlay(
//                                Circle()
//                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
//                            )
//                    }
                } else {
                    // Botón Follow/Following
                    Button {
                        handleFollowTap()
                    } label: {
                        HStack(spacing: 4) {
                            if isFollowLoading {
                                ProgressView()
                                    .tint(followService.isFollowing(user.uid) ? .white : .black)
                                    .scaleEffect(0.7)
                            }
                            
                            Text(followService.isFollowing(user.uid) ? "Following" : "Follow")
                                .font(.system(size: 14, weight: .bold))
                        }
                        .foregroundColor(followService.isFollowing(user.uid) ? .white : .black)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .frame(minWidth: 100)
                        .background(followService.isFollowing(user.uid) ? Color.clear : Color.white)
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(0.5), lineWidth: followService.isFollowing(user.uid) ? 1 : 0)
                        )
                        .clipShape(Capsule())
                    }
                    .disabled(isFollowLoading)
                }
            }
            .padding(.top, 8)
        }
        .padding(.horizontal)
        .sheet(isPresented: $showEditProfile, onDismiss: {
            // Refrescar datos del servidor después de un momento
            Task {
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
                await authVM.fetchCurrentUser()
                onProfileUpdated?()
            }
        }) {
            EditProfileView(profileVM: profileVM, user: user)
                .environmentObject(authVM)
        }
        .alert("Sign out?", isPresented: $showSignOutAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Sign out", role: .destructive) {
                authVM.signOut()
            }
        } message: {
            Text("You can always access your content by signing back in")
        }
        .task {
            if !isOwnProfile {
                _ = await followService.checkIfFollowing(targetUserId: user.uid)
                await followService.loadUserCounts(userId: user.uid)
            }
        }
    }
    
    private func handleFollowTap() {
        isFollowLoading = true
        
        Task {
            do {
                try await followService.toggleFollow(targetUserId: user.uid)
            } catch {
                print("❌ Error toggling follow: \(error.localizedDescription)")
            }
            
            await MainActor.run {
                isFollowLoading = false
            }
        }
    }
}
