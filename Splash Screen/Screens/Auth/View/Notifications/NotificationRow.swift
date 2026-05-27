//
//  NotificationRow.swift
//  Splash Screen
//
//  Created by Alexis Horteales Espinosa on 19/01/26.
//
import SwiftUI

struct NotificationRow: View {
    
    let notification: JamNotification
    let onTapProfile: () -> Void
    let onTapJam: () -> Void
    
    @StateObject private var followService = FollowService.shared
    @State private var userImage: UIImage?
    @State private var trackImage: UIImage?
    
    private var isFollowing: Bool {
        followService.isFollowing(notification.fromUserId)
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // User Avatar - Tap para ir al perfil
            Button {
                onTapProfile()
            } label: {
                userAvatar
            }
            
            // Notification Text - Tap para ir al jam (si aplica)
            Button {
                if notification.type != .follow {
                    onTapJam()
                }
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    notificationText
                        .foregroundColor(.white)
                        .font(.system(size: 14))
                        .multilineTextAlignment(.leading)
                    
                    Text(notification.timeAgo)
                        .foregroundColor(.gray)
                        .font(.system(size: 12))
                }
            }
            .disabled(notification.type == .follow)
            
            Spacer()
            
            // Right side: Follow button or Track image
            rightContent
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            notification.isRead ? Color.clear : Color.white.opacity(0.03)
        )
        .task {
            await loadImages()
        }
    }
    
    // MARK: - User Avatar
    private var userAvatar: some View {
        Group {
            if let image = userImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.purple.opacity(0.7), .blue.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay {
                        Text(String(notification.fromUsername.prefix(1)).uppercased())
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                    }
            }
        }
        .frame(width: 48, height: 48)
        .clipShape(Circle())
        .overlay(
            // Badge de tipo de notificación
            notificationTypeBadge
                .offset(x: 16, y: 16)
        )
    }
    
    // MARK: - Notification Type Badge
    private var notificationTypeBadge: some View {
        Image(systemName: badgeIcon)
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(.white)
            .frame(width: 20, height: 20)
            .background(badgeColor)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(Color.black, lineWidth: 2)
            )
    }
    
    private var badgeIcon: String {
        switch notification.type {
        case .like: return "heart.fill"
        case .repost: return "arrow.2.squarepath"
        case .follow: return "person.fill.badge.plus"
        case .friendRepost: return "arrow.2.squarepath"
        }
    }
    
    private var badgeColor: Color {
        switch notification.type {
        case .like: return .red
        case .repost: return .green
        case .follow: return .blue
        case .friendRepost: return .green
        }
    }
    
    // MARK: - Notification Text
    private var notificationText: Text {
        switch notification.type {
        case .like:
            if let title = notification.trackTitle {
                return Text("\(notification.fromUsername) ").bold()
                + Text("liked ")
                + Text("\"\(title)\"").italic()
            } else {
                return Text("\(notification.fromUsername) ").bold()
                + Text("liked your jam")
            }
            
        case .repost:
            if let title = notification.trackTitle {
                return Text("\(notification.fromUsername) ").bold()
                + Text("reposted ")
                + Text("\"\(title)\"").italic()
            } else {
                return Text("\(notification.fromUsername) ").bold()
                + Text("reposted your jam")
            }
            
        case .follow:
            return Text("\(notification.fromUsername) ").bold()
            + Text("started following you")
            
        case .friendRepost:
            if let title = notification.trackTitle {
                return Text("\(notification.fromUsername) ").bold()
                + Text("shared ")
                + Text("\"\(title)\"").italic()
            } else {
                return Text("\(notification.fromUsername) ").bold()
                + Text("shared a jam")
            }
        }
    }
    
    // MARK: - Right Content
    @ViewBuilder
    private var rightContent: some View {
        if notification.type == .follow {
            followBackButton
        } else if notification.trackImageUrl != nil {
            // Track image - tappable
            Button {
                onTapJam()
            } label: {
                trackImageView
            }
        }
    }
    
    // MARK: - Follow Back Button
    private var followBackButton: some View {
        Button {
            toggleFollowOptimistic()
        } label: {
            Text(isFollowing ? "Following" : "Follow")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(isFollowing ? .gray : .black)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isFollowing ? Color.gray.opacity(0.25) : Color.white)
                )
                .animation(.easeInOut(duration: 0.15), value: isFollowing)
        }
    }
    
    // MARK: - Track Image
    private var trackImageView: some View {
        Group {
            if let image = trackImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .overlay {
                        Image(systemName: "music.note")
                            .foregroundColor(.gray)
                    }
            }
        }
        .frame(width: 50, height: 50)
        .cornerRadius(10)
    }
    
    // MARK: - Actions
    
    private func toggleFollowOptimistic() {
        let targetId = notification.fromUserId
        let wasFollowing = isFollowing
        
        // UI optimista inmediata
        if wasFollowing {
            followService.followingIds.remove(targetId)
        } else {
            followService.followingIds.insert(targetId)
        }
        
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        
        Task.detached(priority: .background) {
            do {
                if wasFollowing {
                    try await followService.unfollowSilent(targetUserId: targetId)
                } else {
                    try await followService.followSilent(targetUserId: targetId)
                }
            } catch {
                await MainActor.run {
                    if wasFollowing {
                        followService.followingIds.insert(targetId)
                    } else {
                        followService.followingIds.remove(targetId)
                    }
                }
            }
        }
    }
    
    private func loadImages() async {
        // Load user image
        if let urlString = notification.fromUserProfileUrl, !urlString.isEmpty {
            if let cached = ImageCacheService.shared.getImage(for: urlString) {
                await MainActor.run { userImage = cached }
            } else {
                await ImageCacheService.shared.preloadImage(from: urlString)
                if let image = ImageCacheService.shared.getImage(for: urlString) {
                    await MainActor.run { userImage = image }
                }
            }
        }
        
        // Load track image
        if let urlString = notification.trackImageUrl, !urlString.isEmpty {
            if let cached = ImageCacheService.shared.getImage(for: urlString) {
                await MainActor.run { trackImage = cached }
            } else {
                await ImageCacheService.shared.preloadImage(from: urlString)
                if let image = ImageCacheService.shared.getImage(for: urlString) {
                    await MainActor.run { trackImage = image }
                }
            }
        }
    }
}
