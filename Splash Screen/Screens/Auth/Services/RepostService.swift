//
//  RepostService.swift
//  Splash Screen
//
//  Created by Alexis Horteales Espinosa on 16/01/26.
//

import Combine
import Foundation
import FirebaseFirestore
import FirebaseAuth

class RepostService: ObservableObject {
    static let shared = RepostService()
    
    private let db = Firestore.firestore()
    
    @Published var pendingReposts: [Repost] = []
    @Published var isLoadingReposts = false
    @Published var myRepostedTrackIds: Set<String> = []
    @Published var repostCounts: [String: Int] = [:]
    
    private var repostsListener: ListenerRegistration?
    private var followingIds: [String] = []
    
    // Reposts vistos - persistidos
    private var seenRepostIds: Set<String> = []
    private let seenRepostsKey = "seenRepostIds_v3"
    private let maxSeenReposts = 500
    
    // Expiración: 24 horas
    private let expirationTime: TimeInterval = 86400
    
    private init() {
        loadSeenReposts()
    }
    
    private var currentUserId: String? { Auth.auth().currentUser?.uid }
    
    // MARK: - Public Methods
    
    func isReposted(_ trackId: String) -> Bool {
        myRepostedTrackIds.contains(trackId)
    }
    
    func getRepostCount(for trackId: String) -> Int {
        repostCounts[trackId] ?? 0
    }
    
    func fetchRepostCount(for trackId: String) async {
        do {
            let snapshot = try await db.collection("reposts")
                .whereField("trackId", isEqualTo: trackId)
                .getDocuments()
            
            await MainActor.run {
                self.repostCounts[trackId] = snapshot.documents.count
            }
        } catch {}
    }
    
    func optimisticToggleRepost(trackId: String) {
        if myRepostedTrackIds.contains(trackId) {
            myRepostedTrackIds.remove(trackId)
            repostCounts[trackId] = max(0, (repostCounts[trackId] ?? 1) - 1)
        } else {
            myRepostedTrackIds.insert(trackId)
            repostCounts[trackId] = (repostCounts[trackId] ?? 0) + 1
        }
    }
    
    func syncRepostToFirebase(track: AudiusTrack, fromUser user: User, wasReposted: Bool, comment: String? = nil) async throws {
        guard let odei = currentUserId else { return }
        
        let repostId = "\(odei)_\(track.id)"
        let repostRef = db.collection("reposts").document(repostId)
        let userRepostRef = db.collection("users").document(odei).collection("reposts").document(track.id)
        
        if wasReposted {
            try await repostRef.delete()
            try await userRepostRef.delete()
        } else {
            var data: [String: Any] = [
                "trackId": track.id,
                "odei": odei,
                "username": user.username,
                "userProfileUrl": user.profileImageUrl ?? "",
                "repostedAt": FieldValue.serverTimestamp(),
                "trackTitle": track.title,
                "trackArtist": track.user.name,
                "trackArtistHandle": track.user.handle,
                "trackDuration": track.duration,
                "trackImageUrl": track.imageURL ?? ""
            ]
            
            if let comment = comment, !comment.isEmpty {
                data["comment"] = comment
            }
            
            try await repostRef.setData(data)
            try await userRepostRef.setData([
                "trackId": track.id,
                "repostedAt": FieldValue.serverTimestamp()
            ])
        }
    }
    
    // MARK: - Listening
    
    func startListening() {
        guard let myId = currentUserId else { return }
        
        Task {
            do {
                let snapshot = try await db.collection("users")
                    .document(myId)
                    .collection("following")
                    .getDocuments()
                
                let ids = snapshot.documents.map { $0.documentID }
                await MainActor.run {
                    self.followingIds = ids
                    print("👥 RepostService: Siguiendo a \(ids.count) usuarios")
                    self.setupRealtimeListener()
                }
            } catch {
                print("❌ Error obteniendo following: \(error)")
            }
        }
    }
    
    private func setupRealtimeListener() {
        repostsListener?.remove()
        guard !followingIds.isEmpty else {
            print("⚠️ No hay amigos para escuchar reposts")
            return
        }
        
        let cutoffDate = Date().addingTimeInterval(-expirationTime)
        
        for batch in followingIds.chunked(into: 10) {
            repostsListener = db.collection("reposts")
                .whereField("odei", in: batch)
                .whereField("repostedAt", isGreaterThan: Timestamp(date: cutoffDate))
                .order(by: "repostedAt", descending: true)
                .limit(to: 20)
                .addSnapshotListener { [weak self] snapshot, error in
                    guard let self = self, let snapshot = snapshot else {
                        if let error = error {
                            print("❌ Listener error: \(error)")
                        }
                        return
                    }
                    for change in snapshot.documentChanges where change.type == .added {
                        if let repost = self.decodeRepost(from: change.document.data()) {
                            self.handleNewRepost(repost)
                        }
                    }
                }
        }
        
        print("🔴 Listener de reposts iniciado para \(followingIds.count) amigos")
    }
    
    private func handleNewRepost(_ repost: Repost) {
        // No mostrar mis propios reposts
        if repost.odei == currentUserId { return }
        // No mostrar si ya lo vi
        if seenRepostIds.contains(repost.id) { return }
        // No mostrar si ya está en pendientes
        if pendingReposts.contains(where: { $0.id == repost.id }) { return }
        // No mostrar si expiró (más de 24 horas)
        if Date().timeIntervalSince(repost.repostedAt) > expirationTime { return }
        // ✅ SOLO mostrar si es de alguien que sigo
        if !followingIds.contains(repost.odei) { return }
        
        print("🆕 Nuevo repost de amigo: \(repost.trackTitle) por @\(repost.username)")
        
        DispatchQueue.main.async {
            self.pendingReposts.insert(repost, at: 0)
        }
    }
    
    func getNextPendingRepost() -> Repost? {
        // Limpiar expirados primero
        pendingReposts.removeAll { Date().timeIntervalSince($0.repostedAt) > expirationTime }
        
        guard !pendingReposts.isEmpty else { return nil }
        let repost = pendingReposts.removeFirst()
        markAsSeen(repostId: repost.id)
        return repost
    }
    
    // MARK: - Fetch Reposts
    
    func fetchInitialReposts() async -> [Repost] {
        guard let myId = currentUserId else { return [] }
        await MainActor.run { self.isLoadingReposts = true }
        
        do {
            // Cargar followingIds si no los tenemos
            if followingIds.isEmpty {
                let snapshot = try await db.collection("users")
                    .document(myId)
                    .collection("following")
                    .getDocuments()
                followingIds = snapshot.documents.map { $0.documentID }
            }
            
            guard !followingIds.isEmpty else {
                print("⚠️ No tienes amigos, no hay reposts")
                await MainActor.run { self.isLoadingReposts = false }
                return []
            }
            
            var allReposts: [Repost] = []
            var addedIds: Set<String> = []
            let cutoffDate = Date().addingTimeInterval(-expirationTime)
            
            for batch in followingIds.chunked(into: 10) {
                let snapshot = try await db.collection("reposts")
                    .whereField("odei", in: batch)
                    .whereField("repostedAt", isGreaterThan: Timestamp(date: cutoffDate))
                    .order(by: "repostedAt", descending: true)
                    .limit(to: 50)
                    .getDocuments()
                
                for doc in snapshot.documents {
                    if let repost = decodeRepost(from: doc.data()) {
                        // No mis reposts
                        if repost.odei == myId { continue }
                        // No vistos
                        if seenRepostIds.contains(repost.id) { continue }
                        // No duplicados
                        if addedIds.contains(repost.id) { continue }
                        // No expirados
                        if Date().timeIntervalSince(repost.repostedAt) > expirationTime { continue }
                        // ✅ SOLO de amigos
                        if !followingIds.contains(repost.odei) { continue }
                        
                        allReposts.append(repost)
                        addedIds.insert(repost.id)
                    }
                }
            }
            
            allReposts.sort { $0.repostedAt > $1.repostedAt }
            await MainActor.run { self.isLoadingReposts = false }
            
            print("📥 \(allReposts.count) reposts de amigos cargados")
            return Array(allReposts.prefix(20))
            
        } catch {
            print("❌ Error cargando reposts: \(error)")
            await MainActor.run { self.isLoadingReposts = false }
            return []
        }
    }
    
    // ✅ CORREGIDO: Solo mostrar reposts de AMIGOS para este track
    func fetchRepostsForTrack(_ trackId: String) async -> [Repost] {
        guard let myId = currentUserId else { return [] }
        
        // Asegurar que tenemos followingIds
        if followingIds.isEmpty {
            do {
                let snapshot = try await db.collection("users")
                    .document(myId)
                    .collection("following")
                    .getDocuments()
                followingIds = snapshot.documents.map { $0.documentID }
            } catch {
                return []
            }
        }
        
        guard !followingIds.isEmpty else { return [] }
        
        do {
            var allReposts: [Repost] = []
            let cutoffDate = Date().addingTimeInterval(-expirationTime)
            
            // Buscar reposts de este track SOLO de amigos
            for batch in followingIds.chunked(into: 10) {
                let snapshot = try await db.collection("reposts")
                    .whereField("trackId", isEqualTo: trackId)
                    .whereField("odei", in: batch)
                    .whereField("repostedAt", isGreaterThan: Timestamp(date: cutoffDate))
                    .order(by: "repostedAt", descending: true)
                    .limit(to: 10)
                    .getDocuments()
                
                for doc in snapshot.documents {
                    if let repost = decodeRepost(from: doc.data()) {
                        // No mis reposts
                        if repost.odei == myId { continue }
                        // No expirados
                        if Date().timeIntervalSince(repost.repostedAt) > expirationTime { continue }
                        
                        allReposts.append(repost)
                    }
                }
            }
            
            allReposts.sort { $0.repostedAt > $1.repostedAt }
            return Array(allReposts.prefix(5))
            
        } catch {
            print("❌ Error fetching reposts for track: \(error)")
            return []
        }
    }
    
    func fetchMyReposts() async {
        guard let odei = currentUserId else { return }
        do {
            let snapshot = try await db.collection("users")
                .document(odei)
                .collection("reposts")
                .getDocuments()
            let ids = Set(snapshot.documents.map { $0.documentID })
            await MainActor.run { self.myRepostedTrackIds = ids }
        } catch {}
    }
    
    // MARK: - Seen Management
    
    func markAsSeen(repostId: String) {
        seenRepostIds.insert(repostId)
        saveSeenReposts()
    }
    
    private func loadSeenReposts() {
        if let data = UserDefaults.standard.data(forKey: seenRepostsKey),
           let ids = try? JSONDecoder().decode(Set<String>.self, from: data) {
            seenRepostIds = ids
        }
    }
    
    private func saveSeenReposts() {
        var toSave = seenRepostIds
        if toSave.count > maxSeenReposts {
            toSave = Set(Array(toSave).suffix(maxSeenReposts))
        }
        
        if let data = try? JSONEncoder().encode(toSave) {
            UserDefaults.standard.set(data, forKey: seenRepostsKey)
        }
    }
    
    func clearSeenHistory() {
        seenRepostIds = []
        UserDefaults.standard.removeObject(forKey: seenRepostsKey)
    }
    
    // MARK: - Helpers
    
    func toTrack(_ repost: Repost) -> AudiusTrack {
        var artwork: Artwork? = nil
        if let url = repost.trackImageUrl, !url.isEmpty {
            artwork = Artwork(small: url, medium: url, large: url)
        }
        return AudiusTrack(
            id: repost.trackId, title: repost.trackTitle, duration: repost.trackDuration,
            artwork: artwork, coverPhoto: nil,
            user: AudiusUser(name: repost.trackArtist, handle: repost.trackArtistHandle),
            playCount: nil, favoriteCount: nil
        )
    }
    
    private func decodeRepost(from data: [String: Any]) -> Repost? {
        guard let trackId = data["trackId"] as? String,
              let odei = data["odei"] as? String,
              let username = data["username"] as? String,
              let trackTitle = data["trackTitle"] as? String,
              let trackArtist = data["trackArtist"] as? String,
              let trackArtistHandle = data["trackArtistHandle"] as? String,
              let trackDuration = data["trackDuration"] as? Int else { return nil }
        
        let repostedAt = (data["repostedAt"] as? Timestamp)?.dateValue() ?? Date()
        let comment = data["comment"] as? String
        
        return Repost(
            trackId: trackId, odei: odei, username: username,
            userProfileUrl: data["userProfileUrl"] as? String,
            repostedAt: repostedAt,
            trackTitle: trackTitle, trackArtist: trackArtist,
            trackArtistHandle: trackArtistHandle, trackDuration: trackDuration,
            trackImageUrl: data["trackImageUrl"] as? String,
            comment: comment
        )
    }
    
    // MARK: - Cleanup
    
    func stopListening() {
        repostsListener?.remove()
        repostsListener = nil
    }
    
    func resetOnLogout() {
        stopListening()
        pendingReposts = []
        myRepostedTrackIds = []
        repostCounts = [:]
        followingIds = []
    }
}

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}
