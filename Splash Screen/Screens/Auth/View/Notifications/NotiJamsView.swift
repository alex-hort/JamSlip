//
//  NotiJamsView.swift
//  Splash Screen
//
//  Created by Alexis Horteales Espinosa on 31/01/26.
//

import SwiftUI
import FirebaseFirestore
import FirebaseAuth

/// Vista unificada para ver Jams desde notificaciones
struct NotiJamsView: View {
    let notification: JamNotification
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var audioPlayer = AudioPlayerManager.shared
    @EnvironmentObject var authVM: AuthViewModel
    
    // Content states
    @State private var jam: Jam?
    @State private var audiusTrack: AudiusTrack?
    @State private var isLoading = true
    
    // Interaction states
    @State private var isLiked = false
    @State private var isSaved = false
    @State private var isReposted = false
    @State private var likesCount = 0
    @State private var repostsCount = 0
    @State private var savesCount = 0
    
    private let db = Firestore.firestore()
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                NotiJamsHeader {
                    audioPlayer.stop()
                    dismiss()
                }
                .padding(.top, 10)
                
                if isLoading {
                    Spacer()
                    NotiJamsLoadingView()
                    Spacer()
                } else if jam != nil || audiusTrack != nil {
                    cardContent
                        .padding(.top, 8)
                    Spacer(minLength: 20)
                } else {
                    Spacer()
                    NotiJamsErrorView()
                    Spacer()
                }
                
                NotiJamsFooter(notification: notification)
                    .padding(.bottom, 34)
            }
        }
        .navigationBarHidden(true)
        .task {
            await loadContent()
            await checkInteractionStatus()
        }
        .onDisappear {
            audioPlayer.stop()
        }
    }
    
    // MARK: - Card Content
    private var cardContent: some View {
        GeometryReader { geo in
            let cardWidth = geo.size.width - 24
            let cardHeight = min(geo.size.height - 10, 500)

            VStack {
                if let jam = jam {
                    NotiJamsCardView(
                        jam: jam,
                        width: cardWidth,
                        height: cardHeight,
                        isPlaying: audioPlayer.currentJam?.id == jam.id && audioPlayer.isPlaying,
                        isLiked: isLiked,
                        isSaved: isSaved,
                        isReposted: isReposted,
                        likesCount: likesCount,
                        repostsCount: repostsCount,
                        savesCount: savesCount,
                        onPlayTap: { audioPlayer.togglePlayPause(for: jam) },
                        onLikeTap: { toggleLikeJam(jam) },
                        onRepostTap: { toggleRepostJam(jam) },
                        onSaveTap: { toggleSaveJam(jam) }
                    )
                } else if let track = audiusTrack {
                    NotiJamsAudiusCardView(
                        track: track,
                        width: cardWidth,
                        height: cardHeight,
                        isPlaying: audioPlayer.currentTrack?.id == track.id && audioPlayer.isPlaying,
                        isLiked: isLiked,
                        isSaved: isSaved,
                        isReposted: isReposted,
                        likesCount: likesCount,
                        repostsCount: repostsCount,
                        onPlayTap: { audioPlayer.togglePlayPause(for: track) },
                        onLikeTap: { toggleLikeTrack(track) },
                        onRepostTap: { toggleRepostTrack(track) },
                        onSaveTap: { toggleSaveTrack(track) }
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.horizontal, 12)
    }

    
    // MARK: - Load Content
    private func loadContent() async {
        guard let trackId = notification.trackId else {
            isLoading = false
            return
        }
        
        // Intentar Jam Premium
        if let loadedJam = await loadJamPremium(trackId: trackId) {
            jam = loadedJam
            likesCount = loadedJam.likesCount
            repostsCount = loadedJam.repostsCount
            savesCount = loadedJam.savesCount
            isLoading = false
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                audioPlayer.playJam(loadedJam)
            }
            return
        }
        
        // Intentar Audius
        if let loadedTrack = await loadAudiusTrack(trackId: trackId) {
            audiusTrack = loadedTrack
            
            // Cargar counts desde Firebase
            await UserJamsService.shared.fetchGlobalCounts(for: trackId)
            likesCount = UserJamsService.shared.getLikesCount(for: trackId)
            
            // Cargar repost count
            await RepostService.shared.fetchRepostCount(for: trackId)
            repostsCount = RepostService.shared.getRepostCount(for: trackId)
            
            isLoading = false
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                audioPlayer.play(track: loadedTrack)
            }
            return
        }
        
        isLoading = false
    }
    
    private func loadJamPremium(trackId: String) async -> Jam? {
        do {
            let doc = try await db.collection("jamsPremium").document(trackId).getDocument()
            guard let data = doc.data() else { return nil }
            
            guard let id = data["id"] as? String,
                  let userId = data["userId"] as? String,
                  let username = data["username"] as? String,
                  let title = data["title"] as? String,
                  let description = data["description"] as? String,
                  let genre = data["genre"] as? String,
                  let moods = data["moods"] as? [String],
                  let audioUrl = data["audioUrl"] as? String,
                  let duration = data["duration"] as? Int else {
                return nil
            }
            
            var createdAt = Date()
            if let timestamp = data["createdAt"] as? Timestamp {
                createdAt = timestamp.dateValue()
            }
            
            return Jam(
                id: id,
                userId: userId,
                username: username,
                userProfileImageUrl: data["userProfileImageUrl"] as? String,
                title: title,
                description: description,
                genre: genre,
                moods: moods,
                audioUrl: audioUrl,
                artworkUrl: data["artworkUrl"] as? String,
                duration: duration,
                createdAt: createdAt,
                likesCount: data["likesCount"] as? Int ?? 0,
                repostsCount: data["repostsCount"] as? Int ?? 0,
                savesCount: data["savesCount"] as? Int ?? 0,
                playsCount: data["playsCount"] as? Int ?? 0
            )
        } catch {
            return nil
        }
    }
    
    private func loadAudiusTrack(trackId: String) async -> AudiusTrack? {
        // Firebase
        do {
            let doc = try await db.collection("jams").document(trackId).getDocument()
            
            if let data = doc.data(),
               let title = data["title"] as? String,
               let duration = data["duration"] as? Int {
                
                let username = data["username"] as? String ?? "Unknown"
                let handle = data["handle"] as? String ?? username
                let artworkUrl = data["artworkUrl"] as? String
                
                return AudiusTrack(
                    id: trackId,
                    title: title,
                    duration: duration,
                    artwork: artworkUrl != nil ? Artwork(small: artworkUrl, medium: artworkUrl, large: artworkUrl) : nil,
                    coverPhoto: nil,
                    user: AudiusUser(name: username, handle: handle),
                    playCount: data["playCount"] as? Int,
                    favoriteCount: data["favoriteCount"] as? Int
                )
            }
        } catch {}
        
        // Audius API
        do {
            let url = URL(string: "https://api.audius.co/v1/tracks/\(trackId)?app_name=JamSlip")!
            let (data, _) = try await URLSession.shared.data(from: url)
            
            struct SingleTrackResponse: Codable { let data: AudiusTrack }
            let response = try JSONDecoder().decode(SingleTrackResponse.self, from: data)
            return response.data
        } catch {
            return nil
        }
    }
    
    // MARK: - Check Status
    private func checkInteractionStatus() async {
        guard let _ = Auth.auth().currentUser?.uid else { return }
        
        if let jam = jam {
            isLiked = await MyJamsService.shared.isJamLiked(jam.id)
            isSaved = await MyJamsService.shared.isJamSaved(jam.id)
            isReposted = JamRepostService.shared.isReposted(jam.id)
        } else if let track = audiusTrack {
            isLiked = UserJamsService.shared.isLiked(track)
            isSaved = UserJamsService.shared.isSaved(track)
            isReposted = RepostService.shared.isReposted(track.id)
        }
    }
    
    // MARK: - Jam Actions
    private func toggleLikeJam(_ jam: Jam) {
        isLiked.toggle()
        likesCount += isLiked ? 1 : -1
        Task { try? await MyJamsService.shared.toggleLike(jam) }
    }
    
    private func toggleSaveJam(_ jam: Jam) {
        isSaved.toggle()
        savesCount += isSaved ? 1 : -1
        Task { try? await MyJamsService.shared.toggleSave(jam) }
    }
    
    private func toggleRepostJam(_ jam: Jam) {
        guard let user = authVM.currentUser else { return }
        isReposted.toggle()
        repostsCount += isReposted ? 1 : -1
        JamRepostService.shared.optimisticToggleRepost(jamId: jam.id)
        Task {
            try? await JamRepostService.shared.syncRepostToFirebase(
                jam: jam, fromUser: user, wasReposted: !isReposted, comment: nil
            )
        }
    }
    
    // MARK: - Track Actions (Audius)
    private func toggleLikeTrack(_ track: AudiusTrack) {
        let wasLiked = isLiked
        isLiked.toggle()
        likesCount += isLiked ? 1 : -1
        
        UserJamsService.shared.optimisticToggleLike(track)
        
        Task {
            try? await UserJamsService.shared.syncLikeToFirebase(track, wasLiked: wasLiked)
        }
    }
    
    private func toggleSaveTrack(_ track: AudiusTrack) {
        let wasSaved = isSaved
        isSaved.toggle()
        
        UserJamsService.shared.optimisticToggleSave(track)
        
        Task {
            try? await UserJamsService.shared.syncSaveToFirebase(track, wasSaved: wasSaved)
        }
    }
    
    private func toggleRepostTrack(_ track: AudiusTrack) {
        guard let user = authVM.currentUser else { return }
        
        let wasReposted = isReposted
        isReposted.toggle()
        
        RepostService.shared.optimisticToggleRepost(trackId: track.id)
        
        Task {
            try? await RepostService.shared.syncRepostToFirebase(
                track: track,
                fromUser: user,
                wasReposted: wasReposted,
                comment: nil
            )
        }
    }
}
