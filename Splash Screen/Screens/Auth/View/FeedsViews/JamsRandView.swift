//
//  JamsRandView.swift
//  Splash Screen
//
//  Created by Alexis Horteales Espinosa on 14/01/26.
//
import SwiftUI
import AVFoundation
import Combine

struct JamsRandView: View {
    @State private var feedItems: [FeedItem] = []
    @State private var isLoading = true
    @State private var currentItemId: String?
    @State private var isLoadingMore = false
    @State private var currentIndex: Int = 0

    @StateObject private var audioPlayer = AudioPlayerManager.shared
    @StateObject private var userJamsService = UserJamsService.shared
    @StateObject private var repostService = RepostService.shared
    @EnvironmentObject var authVM: AuthViewModel
    
    @State private var repostCheckTimer: Timer?
    @State private var visibleReposts: [VisibleRepost] = []
    @State private var addedRepostIds: Set<String> = []
    @State private var sessionTrackIds: Set<String> = []
    
    // Tracks de reposts ya vistos (persistido para que no vuelvan a salir NUNCA)
    @State private var seenRepostTrackIds: Set<String> = []
    private let seenRepostTracksKey = "seenRepostTrackIds_v1"
    
    private let preloadThreshold = 8
    private let batchSize = 20
    private let maxDurationSeconds = 360
    
    // AdMob - PRODUCCIÓN
    private let adUnitID = "ca-app-pub-7808762386002485/1513584451"
    private let adFrequency = 7
    
    // Contador de tracks vistos para ads
    @State private var tracksSeenCount = 0

    var body: some View {
        ZStack {
            Color.black
            
            if isLoading {
                TabView{
                    ForEach(0..<4, id: \.self){ _ in
                        FeedSkeletonCard()
                    }
                }
                
                
            } else if feedItems.isEmpty {
                TabView {
                    ForEach(0..<4, id: \.self) { _ in
                        //FeedEmptyStateCard()
                        FeedSkeletonCard()
                    }
                }
              
            } else {
                TabView(selection: $currentItemId) {
                    ForEach(feedItems) { item in
                        Group {
                            if item.isAd, let unitID = item.adUnitID {
                                AdFeedCardView(adUnitID: unitID)
                                    .id(item.id)
                            } else {
                                FeedCardView(
                                    item: item,
                                    visibleReposts: visibleReposts.filter { $0.trackId == item.track.id },
                                    onLike: { loadRecommendations(for: item.track) },
                                    onRepostSeen: { markRepostTrackAsSeen($0, trackId: item.track.id) }
                                )
                                .environmentObject(authVM)
                            }
                        }
                        .tag(item.id)
                        .onAppear {
                            handleItemAppear(item)
                        }
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
        }
        .onChange(of: currentItemId) { _, newId in
            guard let itemId = newId,
                  let item = feedItems.first(where: { $0.id == itemId }) else { return }
            
            if !item.isAd {
                audioPlayer.playAutomatically(track: item.track)
                MusicService.shared.markTrackAsShown(item.track.id)
                loadRepostsForCurrentTrack(item.track.id)
                
                // Si es un repost, marcar el track como visto para que NUNCA vuelva
                if item.repostInfo != nil {
                    markRepostTrackAsPermanentlySeen(item.track.id)
                }
                
                tracksSeenCount += 1
                if tracksSeenCount % adFrequency == 0 {
                    insertAdAfterCurrent()
                }
            } else {
                audioPlayer.pause()
            }
        }
        // Observar nuevos reposts en tiempo real
        .onChange(of: repostService.pendingReposts.count) { oldCount, newCount in
            if newCount > oldCount {
                // Hay nuevos reposts, insertarlos
                insertNewRepostsInRealTime()
            }
        }
        .task {
            loadSeenRepostTracks()
            AdManager.shared.preloadAds()
            await loadInitialFeed()
            startRepostTimer()
        }
        .onDisappear { stopRepostTimer() }
    }
    
    // MARK: - Seen Repost Tracks (Persistido - NUNCA vuelven)
    
    private func loadSeenRepostTracks() {
        if let data = UserDefaults.standard.data(forKey: seenRepostTracksKey),
           let ids = try? JSONDecoder().decode(Set<String>.self, from: data) {
            seenRepostTrackIds = ids
            print("📂 Tracks de reposts ya vistos: \(ids.count)")
        }
    }
    
    private func saveSeenRepostTracks() {
        var toSave = seenRepostTrackIds
        if toSave.count > 1000 {
            toSave = Set(Array(toSave).suffix(1000))
        }
        
        if let data = try? JSONEncoder().encode(toSave) {
            UserDefaults.standard.set(data, forKey: seenRepostTracksKey)
        }
    }
    
    private func markRepostTrackAsPermanentlySeen(_ trackId: String) {
        seenRepostTrackIds.insert(trackId)
        saveSeenRepostTracks()
        print("👁️ Track marcado como visto permanentemente: \(trackId)")
    }
    
    private func markRepostTrackAsSeen(_ repostId: String, trackId: String) {
        repostService.markAsSeen(repostId: repostId)
        markRepostTrackAsPermanentlySeen(trackId)
    }
    
    // MARK: - Insert New Reposts in Real Time
    
    private func insertNewRepostsInRealTime() {
        guard let repost = repostService.getNextPendingRepost() else { return }
        
        // No insertar si ya vimos este track en un repost antes (NUNCA vuelve)
        guard !seenRepostTrackIds.contains(repost.trackId) else {
            print("⏭️ Repost ignorado - track ya visto: \(repost.trackTitle)")
            return
        }
        guard !sessionTrackIds.contains(repost.trackId) else { return }
        
        let track = repostService.toTrack(repost)
        let item = FeedItem.repost(repost, track)
        
        // Insertar 2 posiciones adelante del actual
        let insertIndex = min(currentIndex + 2, feedItems.count)
        
        DispatchQueue.main.async {
            if !self.feedItems.contains(where: { $0.id == item.id }) {
                self.feedItems.insert(item, at: insertIndex)
                self.sessionTrackIds.insert(repost.trackId)
                self.addVisibleRepost(repost)
                print("🆕 Repost insertado en tiempo real: \(repost.trackTitle) por @\(repost.username)")
            }
        }
    }
    
    // MARK: - Insert Ad
    
    private func insertAdAfterCurrent() {
        guard let currentId = currentItemId,
              let idx = feedItems.firstIndex(where: { $0.id == currentId }) else { return }
        
        let insertIdx = min(idx + 1, feedItems.count)
        
        if insertIdx < feedItems.count && feedItems[insertIdx].isAd {
            return
        }
        
        let uniqueAdID = UUID().uuidString
        let adItem = FeedItem.ad(adUnitID, uniqueAdID)
        
        feedItems.insert(adItem, at: insertIdx)
        print("📺 Ad insertado en posición \(insertIdx)")
    }
    
    // MARK: - Item Handling
    
    private func handleItemAppear(_ item: FeedItem) {
        if let idx = feedItems.firstIndex(where: { $0.id == item.id }) {
            currentIndex = idx
            preloadUpcomingTracks(from: idx)
            
            let remaining = feedItems.count - idx - 1
            
            if remaining <= preloadThreshold && !isLoadingMore {
                loadMoreTracksInfinitely()
            }
            
            // Intentar insertar repost pendiente cada 4 tracks
            if idx > 0 && idx % 4 == 0 {
                insertPendingRepost(after: idx)
            }
        }
    }
    
    private func loadRepostsForCurrentTrack(_ trackId: String) {
        Task {
            // Cargar el count de reposts para este track
            await repostService.fetchRepostCount(for: trackId)
            
            let reposts = await repostService.fetchRepostsForTrack(trackId)
            await MainActor.run {
                for repost in reposts {
                    addVisibleRepost(repost)
                }
            }
        }
    }
    
    // MARK: - Repost Timer
    
    private func startRepostTimer() {
        repostCheckTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
            checkAndInsertNewReposts()
        }
    }
    
    private func stopRepostTimer() {
        repostCheckTimer?.invalidate()
        repostCheckTimer = nil
    }
    
    private func checkAndInsertNewReposts() {
        guard !repostService.pendingReposts.isEmpty else { return }
        insertNewRepostsInRealTime()
    }
    
    private func insertPendingRepost(after index: Int) {
        guard let repost = repostService.getNextPendingRepost() else { return }
        
        // No insertar si ya vimos este track (NUNCA vuelve)
        guard !seenRepostTrackIds.contains(repost.trackId) else { return }
        guard !sessionTrackIds.contains(repost.trackId) else { return }
        
        let track = repostService.toTrack(repost)
        let item = FeedItem.repost(repost, track)
        let insertIndex = min(index + 1, feedItems.count)
        
        if !feedItems.contains(where: { $0.id == item.id }) {
            feedItems.insert(item, at: insertIndex)
            sessionTrackIds.insert(repost.trackId)
            addVisibleRepost(repost)
        }
    }
    
    private func addVisibleRepost(_ repost: Repost) {
        guard !addedRepostIds.contains(repost.id) else { return }
        
        let colors: [Color] = [.green, .pink, .yellow, .orange, .cyan, .purple, .mint]
        let randomColor = colors.randomElement() ?? .green
        
        let visible = VisibleRepost(
            id: repost.id,
            trackId: repost.trackId,
            username: repost.username,
            profileUrl: repost.userProfileUrl,
            trackTitle: repost.trackTitle,
            comment: repost.comment,
            color: randomColor,
            repostedAt: repost.repostedAt
        )
        
        visibleReposts.append(visible)
        addedRepostIds.insert(repost.id)
    }
    
    // MARK: - Filters
    
    private func filterByDuration(_ tracks: [AudiusTrack]) -> [AudiusTrack] {
        tracks.filter { $0.duration <= maxDurationSeconds }
    }
    
    private func filterSessionDuplicates(_ tracks: [AudiusTrack]) -> [AudiusTrack] {
        tracks.filter { !sessionTrackIds.contains($0.id) }
    }
    
    // MARK: - Load Initial Feed
    
    @MainActor
    func loadInitialFeed() async {
        isLoading = true
        
        visibleReposts = []
        addedRepostIds = []
        sessionTrackIds = []
        feedItems = []
        tracksSeenCount = 0
        
        await userJamsService.fetchAllUserJams()
        await repostService.fetchMyReposts()
        repostService.startListening()
        
        do {
            async let tracksTask = MusicService.shared.getPersonalizedTracks(limit: 50)
            async let repostsTask = repostService.fetchInitialReposts()
            
            let (allTracks, reposts) = try await (tracksTask, repostsTask)
            let tracks = filterByDuration(allTracks)
            
            print("📥 Tracks recibidos: \(allTracks.count), después de filtro: \(tracks.count)")
            
            var items: [FeedItem] = []
            
            // Filtrar reposts: no mostrar si ya vimos ese track NUNCA
            for repost in reposts.prefix(10) {
                if repost.trackDuration <= maxDurationSeconds &&
                   !sessionTrackIds.contains(repost.trackId) &&
                   !seenRepostTrackIds.contains(repost.trackId) {
                    let track = repostService.toTrack(repost)
                    items.append(.repost(repost, track))
                    sessionTrackIds.insert(repost.trackId)
                    addVisibleRepost(repost)
                }
            }
            
            for track in tracks {
                if !sessionTrackIds.contains(track.id) {
                    items.append(.track(track))
                    sessionTrackIds.insert(track.id)
                }
            }
            
            feedItems = items
            
            print("✅ Feed inicial: \(feedItems.count) items")
            
            Task.detached(priority: .background) {
                await MusicService.shared.preloadAlbumArt(for: tracks)
            }
            
            if !feedItems.isEmpty {
                currentItemId = feedItems[0].id
                audioPlayer.playAutomatically(track: feedItems[0].track)
                loadRepostsForCurrentTrack(feedItems[0].track.id)
            }
        } catch {
            print("❌ Error cargando feed: \(error)")
        }
        
        isLoading = false
    }
    
    // MARK: - Preload
    
    func preloadUpcomingTracks(from currentIndex: Int) {
        let endIndex = min(currentIndex + 10, feedItems.count)
        guard currentIndex < endIndex else { return }
        
        let tracks = feedItems[currentIndex..<endIndex]
            .filter { !$0.isAd }
            .map { $0.track }
        
        Task.detached(priority: .background) {
            await MusicService.shared.preloadAlbumArt(for: tracks)
        }
    }
    
    // MARK: - Load More
    
    func loadRecommendations(for track: AudiusTrack) {
        Task {
            do {
                let allRecs = try await MusicService.shared.getRecommendations(for: track)
                let recs = filterByDuration(allRecs)
                let newRecs = filterSessionDuplicates(recs)
                
                await MainActor.run {
                    if !newRecs.isEmpty,
                       let idx = feedItems.firstIndex(where: { $0.track.id == track.id }) {
                        let insertIdx = min(idx + 1, feedItems.count)
                        
                        for rec in newRecs.prefix(5).reversed() {
                            feedItems.insert(.track(rec), at: insertIdx)
                            sessionTrackIds.insert(rec.id)
                        }
                        print("➕ Agregadas \(newRecs.prefix(5).count) recomendaciones")
                    }
                }
            } catch {
                print("❌ Error recomendaciones: \(error)")
            }
        }
    }
    
    func loadMoreTracksInfinitely() {
        guard !isLoadingMore else { return }
        isLoadingMore = true
        
        Task {
            do {
                let allTracks = try await MusicService.shared.getPersonalizedTracks(limit: batchSize + 20)
                let durationFiltered = filterByDuration(allTracks)
                let newTracks = filterSessionDuplicates(durationFiltered)
                
                await MainActor.run {
                    for track in newTracks.prefix(batchSize) {
                        feedItems.append(.track(track))
                        sessionTrackIds.insert(track.id)
                    }
                    
                    print("✅ Feed actualizado: \(feedItems.count) items")
                    isLoadingMore = false
                }
            } catch {
                print("❌ Error cargando más: \(error)")
                await MainActor.run { isLoadingMore = false }
            }
        }
    }
}
