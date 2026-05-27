//
//  FollowListSheet.swift
//  Splash Screen
//
//  Created by Alexis Horteales Espinosa on 15/01/26.
//
import SwiftUI
struct FollowListSheet: View {
    let user: User
    @Binding var selectedTab: FollowSheetTab
    var onUserTap: ((User) -> Void)?
    
    @StateObject private var followService = FollowService.shared
    @Environment(\.dismiss) private var dismiss
    
    private var realFollowersCount: Int {
        if followService.isLoadingFollowers {
            return followService.getFollowersCount(for: user.uid)
        }
        return followService.followersList.count
    }
    
    private var realFollowingCount: Int {
        if followService.isLoadingFollowing {
            return followService.getFollowingCount(for: user.uid)
        }
        return followService.followingList.count
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                FollowSheetTabsView(
                    followersCount: realFollowersCount,
                    followingCount: realFollowingCount,
                    selectedTab: $selectedTab
                )
                
                Divider()
                    .background(Color.white.opacity(0.15))
                
                if selectedTab == .followers {
                    FollowersListContent(
                        user: user,
                        onUserTap: { tappedUser in
                            dismiss()
                            onUserTap?(tappedUser) // ✅ Sin asyncAfter
                        }
                    )
                } else {
                    FollowingListContent(
                        user: user,
                        onUserTap: { tappedUser in
                            dismiss()
                            onUserTap?(tappedUser) // ✅ Sin asyncAfter
                        }
                    )
                }
            }
            .background(Color.black)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.white)
                    }
                }
                
                ToolbarItem(placement: .principal) {
                    Text(user.username)
                        .font(.headline)
                        .foregroundColor(.white)
                }
            }
        }
        .task {
            await followService.fetchFollowers(for: user.uid)
            await followService.fetchFollowingUsers(for: user.uid)
        }
    }
}
