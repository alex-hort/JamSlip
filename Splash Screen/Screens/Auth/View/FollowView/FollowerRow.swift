//
//  FollowerRow.swift
//  Splash Screen
//
//  Created by Alexis Horteales Espinosa on 14/01/26.
//

import SwiftUI

struct FollowerRow: View {
    let user: User
    let showRemoveButton: Bool
    let onTap: () -> Void
    
    @StateObject private var followService = FollowService.shared
    @State private var showRemoveAlert = false
    @State private var isRemoving = false
    
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
            
            if showRemoveButton {
                Button {
                    showRemoveAlert = true
                } label: {
                    if isRemoving {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(0.8)
                            .frame(width: 80, height: 32)
                    } else {
                        Text("Remove")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 80, height: 32)
                            .background(Color.gray.opacity(0.3))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                .disabled(isRemoving)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .alert("Remove follower?", isPresented: $showRemoveAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Remove", role: .destructive) {
                removeFollower()
            }
        } message: {
            Text("\(user.username) will no longer follow you.")
        }
    }
    
    private func removeFollower() {
        isRemoving = true
        Task {
            do {
                try await followService.removeFollower(followerId: user.uid)
            } catch {
                print("❌ Error removing follower: \(error)")
            }
            await MainActor.run {
                isRemoving = false
            }
        }
    }
}
