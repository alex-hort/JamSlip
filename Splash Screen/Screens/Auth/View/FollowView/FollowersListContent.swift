//
//  FollowersListContent.swift
//  Splash Screen
//
//  Created by Alexis Horteales Espinosa on 15/01/26.
//

import SwiftUI

struct FollowersListContent: View {
    let user: User
    var onUserTap: ((User) -> Void)?
    
    @StateObject private var followService = FollowService.shared
    
    private var isOwnProfile: Bool {
        followService.currentUserId == user.uid
    }
    
    var body: some View {
        Group {
            if followService.isLoadingFollowers {
                Spacer()
                ProgressView()
                    .tint(.white)
                Spacer()
            } else if followService.followersList.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "person.2")
                        .font(.system(size: 50))
                        .foregroundColor(.white.opacity(0.3))
                    Text("No followers yet")
                        .foregroundColor(.white.opacity(0.5))
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        if isOwnProfile {
                            Text("All followers")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal)
                                .padding(.vertical, 12)
                        }
                        
                        ForEach(followService.followersList, id: \.uid) { follower in
                            FollowerRow(
                                user: follower,
                                showRemoveButton: isOwnProfile,
                                onTap: { onUserTap?(follower) }
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
