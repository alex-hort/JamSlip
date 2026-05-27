//
//  FollowingRow.swift
//  Splash Screen
//
//  Created by Alexis Horteales Espinosa on 14/01/26.
//
import SwiftUI

struct FollowingRow: View {
    let user: User
    let showUnfollowButton: Bool
    let onTap: () -> Void
    
    @StateObject private var followService = FollowService.shared
    @State private var showUnfollowAlert = false
    @State private var isUnfollowing = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Foto de perfil
            Button(action: onTap) {
                UserAvatarView(user: user, size: 50)
            }
            
            // Info del usuario
            Button(action: onTap) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(user.username)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text(user.fullName)
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            if showUnfollowButton {
                Button {
                    showUnfollowAlert = true
                } label: {
                    if isUnfollowing {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(0.8)
                            .frame(width: 90, height: 32)
                    } else {
                        Text("Unfollow")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 90, height: 32)
                            .background(Color.gray.opacity(0.3))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                .disabled(isUnfollowing)
                
                // Botón X
                Button {
                    showUnfollowAlert = true
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .alert("Unfollow \(user.username)?", isPresented: $showUnfollowAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Unfollow", role: .destructive) {
                unfollowUser()
            }
        }
    }
    
    private func unfollowUser() {
        isUnfollowing = true
        Task {
            do {
                try await followService.unfollow(targetUserId: user.uid)
            } catch {
                print("❌ Error unfollowing: \(error)")
            }
            await MainActor.run {
                isUnfollowing = false
            }
        }
    }
}
