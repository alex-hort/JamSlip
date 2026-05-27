//
//  UserProfileView.swift
//  Splash Screen
//
//  Created by Alexis Horteales Espinosa on 14/01/26.
//
import SwiftUI

/// Vista para ver el perfil de OTRO usuario (no el tuyo)
struct UserProfileView: View {
    
    let user: User
    
    @State private var offset: CGFloat = 0
    @State private var titleOffset: CGFloat = 0
    @StateObject private var profileVM = ProfileViewModel()
    @StateObject private var audioPlayer = AudioPlayerManager.shared
    @Environment(\.dismiss) private var dismiss
    
    // ✅ Usar el usuario cargado del ViewModel
    private var displayUser: User {
        profileVM.loadedUser ?? user
    }
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                // Header con Banner
                ProfileHeaderView(
                    user: displayUser,
                    offset: $offset,
                    titleOffset: $titleOffset,
                    bannerImage: nil,
                    profileVM: profileVM
                )
                .frame(height: 180)
                
                // Contenido del Perfil
                if profileVM.isLoadingUser {
                    UserProfileSkeletonView()
                } else {
                    ProfileContentView(
                        user: displayUser,
                        profileVM: profileVM,
                        profileImage: nil,
                        isOwnProfile: false
                    )
                }
            }
        }
        .ignoresSafeArea(edges: .top)
        .background(Color.black)
        .preferredColorScheme(.dark)
        .navigationBarBackButtonHidden(true)
        
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(Color.black.opacity(0.6))
                        .clipShape(Circle())
                        .scaleEffect(0.95)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: offset)

                }
                .buttonStyle(.plain)
            }
        }


        .task {
            // ✅ Cargar datos frescos usando ProfileViewModel
            await profileVM.loadFreshUserData(userId: user.uid)
        }
        .onAppear {
            audioPlayer.pause()
        }
    }
}
