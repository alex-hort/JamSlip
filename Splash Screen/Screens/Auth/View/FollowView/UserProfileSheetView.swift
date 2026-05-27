//
//  UserProfileSheetView.swift
//  Splash Screen
//
//  Created by Alexis Horteales Espinosa on 15/01/26.
//

import SwiftUI

struct UserProfileSheetView: View {
    let user: User
    var onUserTap: ((User) -> Void)? = nil
    
    @StateObject private var followService = FollowService.shared
    @StateObject private var userJamsService = UserJamsService.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var navigateToUser: User? = nil
    @State private var showFollowSheet = false
    @State private var selectedTab: FollowSheetTab = .followers
    @State private var likedTracks: [AudiusTrack] = []
    @State private var savedTracks: [AudiusTrack] = []
    @State private var isLoadingTracks = true
    
    private var isOwnProfile: Bool {
        followService.currentUserId == user.uid
    }
    
    private var isFollowing: Bool {
        followService.isFollowing(user.uid)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    profileHeader
                    statsRow
                    if !isOwnProfile {
                        followButton
                    }
                    tracksContent
                }
                .padding()
            }
            .background(Color.black)
            .navigationDestination(item: $navigateToUser) { tappedUser in
                UserProfileView(user: tappedUser)
            }
            // ✅ Solo UN .sheet
            .sheet(isPresented: $showFollowSheet) {
                FollowListSheet(
                    user: user,
                    selectedTab: $selectedTab
                ) { tappedUser in
                    showFollowSheet = false
                    // ✅ Pequeño delay solo para que el sheet cierre antes de navegar
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        navigateToUser = tappedUser
                    }
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
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
            await followService.loadUserCounts(userId: user.uid)
            _ = await followService.checkIfFollowing(targetUserId: user.uid)
            await loadUserTracks()
        }
    }
    


    
    // MARK: - Profile Header
    private var profileHeader: some View {
        VStack(spacing: 12) {
            // Avatar
            if let profileUrl = user.profileImageUrl, !profileUrl.isEmpty {
                AsyncImage(url: URL(string: profileUrl)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    default:
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .overlay {
                                Image(systemName: "person.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.white.opacity(0.5))
                            }
                    }
                }
                .frame(width: 100, height: 100)
                .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 100, height: 100)
                    .overlay {
                        Image(systemName: "person.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.white.opacity(0.5))
                    }
            }
            
            // Name
            Text(user.fullName)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text("@\(user.username)")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
    }
    
    // MARK: - Stats Row
    private var statsRow: some View {
        HStack(spacing: 40) {
            // Following
            Button {
                selectedTab = .following
                showFollowSheet = true
            } label: {
                VStack(spacing: 4) {
                    Text("\(followService.getFollowingCount(for: user.uid))")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    Text("Following")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            // Followers
            Button {
                selectedTab = .followers
                showFollowSheet = true
            } label: {
                VStack(spacing: 4) {
                    Text("\(followService.getFollowersCount(for: user.uid))")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    Text("Followers")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
        }
    }
    
    // MARK: - Follow Button
    private var followButton: some View {
        Button {
            toggleFollow()
        } label: {
            Text(isFollowing ? "Following" : "Follow")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(isFollowing ? .white : .black)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(isFollowing ? Color.gray.opacity(0.3) : Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 22))
        }
        .padding(.horizontal, 40)
    }
    
    // MARK: - Tracks Content
    private var tracksContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            if isLoadingTracks {
                HStack {
                    Spacer()
                    ProgressView().tint(.white)
                    Spacer()
                }
                .padding(.top, 40)
            } else {
                // Liked Tracks
                if !likedTracks.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Liked Jams")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        ForEach(likedTracks.prefix(5), id: \.id) { track in
                            TrackRowView(track: track)
                        }
                    }
                }
                
                // Saved Tracks
                if !savedTracks.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Saved Jams")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        ForEach(savedTracks.prefix(5), id: \.id) { track in
                            TrackRowView(track: track)
                        }
                    }
                }
                
                if likedTracks.isEmpty && savedTracks.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "music.note")
                            .font(.system(size: 40))
                            .foregroundColor(.white.opacity(0.3))
                        Text("No jams yet")
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
                }
            }
        }
        .padding(.top, 20)
    }
    
    // MARK: - Actions
    private func toggleFollow() {
        // Optimistic update - UI instantánea
        if isFollowing {
            followService.followingIds.remove(user.uid)
        } else {
            followService.followingIds.insert(user.uid)
        }
        
        // Sync con Firebase en background
        Task {
            do {
                if followService.isFollowing(user.uid) {
                    // Ya se insertó arriba, ahora sincronizar
                    try await followService.follow(targetUserId: user.uid)
                } else {
                    try await followService.unfollow(targetUserId: user.uid)
                }
            } catch {
                // Revertir en caso de error
                await MainActor.run {
                    if followService.isFollowing(user.uid) {
                        followService.followingIds.remove(user.uid)
                    } else {
                        followService.followingIds.insert(user.uid)
                    }
                }
            }
        }
    }
    
    private func loadUserTracks() async {
        isLoadingTracks = true
        
        do {
            likedTracks = try await userJamsService.fetchLikedTracks(for: user.uid)
            savedTracks = try await userJamsService.fetchSavedTracks(for: user.uid)
        } catch {
            print("❌ Error loading tracks: \(error)")
        }
        
        isLoadingTracks = false
    }
}

// MARK: - Track Row View
struct TrackRowView: View {
    let track: AudiusTrack
    @StateObject private var audioPlayer = AudioPlayerManager.shared
    
    var body: some View {
        HStack(spacing: 12) {
            // Album art
            if let imageURL = track.imageURL {
                AsyncImage(url: URL(string: imageURL)) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                }
                .frame(width: 50, height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 50, height: 50)
                    .overlay {
                        Image(systemName: "music.note")
                            .foregroundColor(.white.opacity(0.5))
                    }
            }
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(track.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text(track.user.name)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Play button
            Button {
                audioPlayer.togglePlayPause(for: track)
            } label: {
                Image(systemName: audioPlayer.currentTrack?.id == track.id && audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.white)
            }
        }
        .padding(.vertical, 4)
    }
}
