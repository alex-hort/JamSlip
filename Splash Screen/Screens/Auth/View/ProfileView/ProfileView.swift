//
//  ProfileView.swift
//  Splash Screen
//
//  Created by Alexis Horteales Espinosa on 05/01/26.
//
import SwiftUI
import PhotosUI

struct ProfileView: View {
    
    @State private var offset: CGFloat = 0
    @State private var titleOffset: CGFloat = 0
    @State private var tabBarOffset: CGFloat = 0
    @State private var refreshID = UUID()
    @State private var selectedUser: User? = nil
    @State private var showUserProfile = false
    
    @EnvironmentObject var authVM: AuthViewModel
    @StateObject private var profileVM = ProfileViewModel()
    @StateObject private var audioPlayer = AudioPlayerManager.shared

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    if let user = authVM.currentUser {
                        ProfileHeaderView(
                            user: user,
                            offset: $offset,
                            titleOffset: $titleOffset,
                            bannerImage: nil,
                            profileVM: profileVM
                        )
                        .id("header-\(refreshID)-\(user.bannerImageUrl ?? "")")
                        .frame(height: 180)
                        
                        ProfileContentView(
                            user: user,
                            profileVM: profileVM,
                            profileImage: nil,
                            onProfileUpdated: { refreshID = UUID() },
                            isOwnProfile: true,
                            onUserTap: { tappedUser in
                                var transaction = Transaction()
                                transaction.disablesAnimations = true
                                
                                withTransaction(transaction) {
                                    selectedUser = tappedUser
                                    showUserProfile = true
                                }
                            }
                        )
                        .id("content-\(refreshID)-\(user.profileImageUrl ?? "")")
                    }
                }
            }
            .ignoresSafeArea(edges: .top)
            .background(Color.black)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: $showUserProfile) {
                if let selectedUser {
                    UserProfileView(user: selectedUser)
                        .transaction { t in
                            t.animation = nil
                        }
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            audioPlayer.pause()
        }
    }
}
