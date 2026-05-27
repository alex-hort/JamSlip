//
//  FollowingListContent.swift
//  Splash Screen
//
//  Created by Alexis Horteales Espinosa on 15/01/26.
//
import SwiftUI

struct FollowingListContent: View {
    let user: User
    var onUserTap: ((User) -> Void)?
    
    @StateObject private var followService = FollowService.shared
    
    private var isOwnProfile: Bool {
        followService.currentUserId == user.uid
    }
    
    var body: some View {
        Group {
            if followService.isLoadingFollowing {
                Spacer()
                ProgressView()
                    .tint(.white)
                Spacer()
            } else if followService.followingList.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 50))
                        .foregroundColor(.white.opacity(0.3))
                    Text("Not following anyone yet")
                        .foregroundColor(.white.opacity(0.5))
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(followService.followingList, id: \.uid) { followingUser in
                            FollowingRow(
                                user: followingUser,
                                showUnfollowButton: isOwnProfile,
                                onTap: { onUserTap?(followingUser) }
                            )
                            
                            Divider()
                                .background(Color.white.opacity(0.1))
                                .padding(.leading, 70)
                        }
                    }
                }
            }
        }
    }
}
