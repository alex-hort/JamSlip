//
//  ProfileStatsView.swift
//  Splash Screen
//
//  Created by Alexis Horteales Espinosa on 08/01/26.
//
import SwiftUI

struct ProfileStatsView: View {
    let user: User
    var onUserTap: ((User) -> Void)? = nil
    
    @StateObject private var followService = FollowService.shared
    
    @State private var showFollowSheet = false
    @State private var selectedTab: FollowSheetTab = .followers
    
    var body: some View {
        HStack(spacing: 16) {
            // Following - tappeable
            Button {
                selectedTab = .following
                showFollowSheet = true
            } label: {
                HStack(spacing: 4) {
                    Text("\(followService.getFollowingCount(for: user.uid))")
                        .foregroundColor(.white)
                        .fontWeight(.bold)
                    
                    Text("Following")
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            
            // Followers - tappeable
            Button {
                selectedTab = .followers
                showFollowSheet = true
            } label: {
                HStack(spacing: 4) {
                    Text(formattedFollowers)
                        .foregroundColor(.white)
                        .fontWeight(.bold)
                    
                    Text("Followers")
                        .foregroundColor(.white.opacity(0.6))
                }
            }
        }
        .font(.subheadline)
        .padding(.horizontal)
        .offset(y: -10)
        .task {
            await followService.loadUserCounts(userId: user.uid)
        }
        .sheet(isPresented: $showFollowSheet) {
            FollowListSheet(
                user: user,
                selectedTab: $selectedTab
            ) { tappedUser in
                showFollowSheet = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    onUserTap?(tappedUser) // ✅ Solo callback, sin navigationDestination
                }
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        // ✅ ELIMINADO el .navigationDestination — lo maneja ProfileView
    }
    
    private var formattedFollowers: String {
        let count = followService.getFollowersCount(for: user.uid)
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        }
        return "\(count)"
    }
}
