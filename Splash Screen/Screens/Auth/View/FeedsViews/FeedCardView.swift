//
//  FeedCardView.swift
//  Splash Screen
//
//  Created by Alexis Horteales Espinosa on 17/01/26.
//
import SwiftUI

struct FeedCardView: View {
    let item: FeedItem
    let visibleReposts: [VisibleRepost]
    var onLike: (() -> Void)? = nil
    var onRepostSeen: ((String) -> Void)? = nil
    
    @StateObject private var audioPlayer = AudioPlayerManager.shared
    @StateObject private var userJamsService = UserJamsService.shared
    @StateObject private var repostService = RepostService.shared
    @EnvironmentObject var authVM: AuthViewModel
    
    @State private var showLikeAnim = false
    @State private var showSaveAnim = false
    @State private var showRepostAnim = false
    
    private var track: AudiusTrack { item.track }
    
    private var isPlaying: Bool {
        audioPlayer.currentTrack?.id == track.id && audioPlayer.isPlaying
    }
    
    var body: some View {
        GeometryReader { geo in
            let cardWidth = geo.size.width - 32
            let cardHeight = geo.size.height - 200
            let cardOriginY: CGFloat = 20
            
            ZStack {
                Color.black
                
                VStack {
                    Spacer().frame(height: cardOriginY)
                    
                    ZStack {
                        AlbumCardView(track: track, width: cardWidth, height: cardHeight)
                        
                        FloatingRepostsView(
                            reposts: visibleReposts,
                            cardWidth: cardWidth,
                            cardHeight: cardHeight
                        )
                    }
                    .frame(width: cardWidth, height: cardHeight)
                    
                    Spacer()
                }
                
                // Controles laterales
                VStack {
                    Spacer()
                    SideControlsView(
                        track: track,
                        showLikeAnim: $showLikeAnim,
                        showSaveAnim: $showSaveAnim,
                        showRepostAnim: $showRepostAnim,
                        onLike: doLike,
                        onSave: doSave,
                        onRepost: doRepost
                    )
                    .padding(.trailing, 18)
                    .padding(.bottom, 160)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
                
                // Info del artista
                VStack {
                    Spacer()
                    
                    ArtistInfoView(track: track)
                        .padding(.leading, 16)
                        .padding(.trailing, 80)
                        .padding(.bottom, 90)
                        .offset(y: cardHeight * 0.04)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Play button
                if !isPlaying {
                    Image(systemName: "play.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.white.opacity(0.8))
                        .shadow(color: .black.opacity(0.5), radius: 10)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                audioPlayer.togglePlayPause(for: track)
            }
        }
        .task {
            await userJamsService.fetchGlobalCounts(for: track.id)
            await repostService.fetchRepostCount(for: track.id)
        }
        .onAppear {
            if let r = item.repostInfo {
                onRepostSeen?(r.id)
            }
        }
    }
    
    // MARK: - Actions
    private func doLike() {
        let wasLiked = userJamsService.isLiked(track)
        userJamsService.optimisticToggleLike(track)
        
        if !wasLiked {
            triggerAnim($showLikeAnim)
            onLike?()
            
            // ✅ Enviar notificación al amigo que reposteó
            if let repostInfo = item.repostInfo {
                print("🔍 RepostInfo encontrado:")
                print("   - odei (quien reposteó): \(repostInfo.odei)")
                print("   - username: \(repostInfo.username)")
                print("   - trackTitle: \(repostInfo.trackTitle)")
                
                if let currentUser = authVM.currentUser {
                    print("   - currentUser: \(currentUser.username)")
                    
                    Task {
                        await NotificationService.shared.sendLikeNotification(
                            toUserId: repostInfo.odei,
                            fromUser: currentUser,
                            track: track
                        )
                        print("💌 Notificación de like enviada a @\(repostInfo.username) (ID: \(repostInfo.odei))")
                    }
                } else {
                    print("❌ currentUser es nil!")
                }
            } else {
                print("⚠️ No es un repost, no se envía notificación de like a amigo")
            }
        } else {
            // Eliminar notificación si hace unlike
            if let repostInfo = item.repostInfo {
                Task {
                    await NotificationService.shared.deleteLikeNotification(
                        toUserId: repostInfo.odei,
                        trackId: track.id
                    )
                }
            }
        }
        
        Task.detached(priority: .background) {
            try? await userJamsService.syncLikeToFirebase(track, wasLiked: wasLiked)
        }
    }
    
    private func doSave() {
        let wasSaved = userJamsService.isSaved(track)
        userJamsService.optimisticToggleSave(track)
        
        if !wasSaved {
            triggerAnim($showSaveAnim)
        }
        
        Task.detached(priority: .background) {
            try? await userJamsService.syncSaveToFirebase(track, wasSaved: wasSaved)
        }
    }
    
    private func doRepost() {
        guard let user = authVM.currentUser else { return }
        
        let wasReposted = repostService.isReposted(track.id)
        repostService.optimisticToggleRepost(trackId: track.id)
        
        if !wasReposted {
            triggerAnim($showRepostAnim)
            
            // Enviar notificación de repost si es un repost de alguien (re-repost)
            if let repostInfo = item.repostInfo {
                Task {
                    await NotificationService.shared.sendRepostNotification(
                        toUserId: repostInfo.odei,
                        fromUser: user,
                        track: track
                    )
                }
            }
            
            // Enviar notificación a todos mis seguidores de que hice un repost
            Task {
                await NotificationService.shared.sendFriendRepostNotification(
                    fromUser: user,
                    track: track
                )
            }
        } else {
            // Si quita el repost, eliminar las notificaciones enviadas a seguidores
            Task {
                await NotificationService.shared.deleteFriendRepostNotifications(trackId: track.id)
            }
        }
        
        Task.detached(priority: .background) {
            try? await repostService.syncRepostToFirebase(
                track: track,
                fromUser: user,
                wasReposted: wasReposted,
                comment: nil
            )
        }
    }
    
    private func triggerAnim(_ binding: Binding<Bool>) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
            binding.wrappedValue = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation { binding.wrappedValue = false }
        }
    }
}
