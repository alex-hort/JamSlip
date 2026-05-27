//
//  JamRepostService.swift
//  Splash Screen
//
//  Created by Alexis Horteales Espinosa on 28/01/26.
//
import Foundation
import FirebaseAuth
import FirebaseFirestore
import Combine
import SwiftUI

@MainActor
class JamRepostService: ObservableObject {
    static let shared = JamRepostService()
    
    private let db = Firestore.firestore()
    private var repostsListener: ListenerRegistration?
    private var followingIds: [String] = []
    
    // Published properties
    @Published var pendingReposts: [JamRepost] = []
    @Published var myRepostedJamIds: Set<String> = []
    @Published var repostCounts: [String: Int] = [:]
    @Published var isLoading = false
    
    // Notificar cambios de counts
    var repostCountsDidChange = PassthroughSubject<Void, Never>()
    
    // Reposts vistos - persistidos
    private var seenRepostIds: Set<String> = []
    private let seenRepostsKey = "seenJamRepostIds_v1"
    private let maxSeenReposts = 500
    
    // Expiración: 24 horas
    private let expirationTime: TimeInterval = 86400
    
    private init() {
        loadSeenReposts()
    }
    
    private var currentUserId: String? { Auth.auth().currentUser?.uid }
    
    // MARK: - Public Methods
    
    func isReposted(_ jamId: String) -> Bool {
        myRepostedJamIds.contains(jamId)
    }
    
    func getRepostCount(for jamId: String) -> Int {
        repostCounts[jamId] ?? 0
    }
    
    // MARK: - Toggle Repost (Optimistic)
    
    func optimisticToggleRepost(jamId: String) {
        if myRepostedJamIds.contains(jamId) {
            myRepostedJamIds.remove(jamId)
            repostCounts[jamId] = max(0, (repostCounts[jamId] ?? 1) - 1)
        } else {
            myRepostedJamIds.insert(jamId)
            repostCounts[jamId] = (repostCounts[jamId] ?? 0) + 1
        }
        // Notificar cambio
        repostCountsDidChange.send()
        objectWillChange.send()
    }
    
    // MARK: - Sync Repost to Firebase
    
    func syncRepostToFirebase(jam: Jam, fromUser: User, wasReposted: Bool, comment: String? = nil) async throws {
        guard let userId = currentUserId else { return }
        
        let repostId = "\(userId)_\(jam.id)"
        let repostRef = db.collection("jamReposts").document(repostId)
        let userRepostRef = db.collection("users").document(userId).collection("jamReposts").document(jam.id)
        let jamRef = db.collection("jamsPremium").document(jam.id)
        
        if wasReposted {
            // Quitar repost
            try await repostRef.delete()
            try await userRepostRef.delete()
            try await jamRef.updateData(["repostsCount": FieldValue.increment(Int64(-1))])
            
            // Eliminar notificaciones
            await NotificationService.shared.deleteJamRepostNotifications(jamId: jam.id)
            
            print("🔄 Repost de jam removido")
        } else {
            // Crear repost
            let repost = JamRepost(
                jamId: jam.id,
                odei: jam.userId,
                originalUsername: jam.username,
                userId: userId,
                username: fromUser.username,
                userProfileUrl: fromUser.profileImageUrl,
                jamTitle: jam.title,
                jamArtworkUrl: jam.artworkUrl,
                jamAudioUrl: jam.audioUrl,
                jamDuration: jam.duration,
                jamGenre: jam.genre,
                jamMoods: jam.moods,
                repostedAt: Date(),
                comment: comment
            )
            
            try await repostRef.setData(repost.toDictionary())
            try await userRepostRef.setData([
                "jamId": jam.id,
                "repostedAt": FieldValue.serverTimestamp()
            ])
            try await jamRef.updateData(["repostsCount": FieldValue.increment(Int64(1))])
            
            // Solo enviar notificaciones si NO es tu propio jam
            if jam.userId != userId {
                // Enviar notificación al dueño del jam
                await NotificationService.shared.sendJamRepostNotification(
                    toUserId: jam.userId,
                    fromUser: fromUser,
                    jam: jam
                )
            }
            
            // Notificar a seguidores (siempre)
            await NotificationService.shared.sendFriendJamRepostNotification(
                fromUser: fromUser,
                jam: jam
            )
            
            // Backend para Vector Search - repost también cuenta como interés fuerte
            await JamSlipAPIService.shared.updateUserTaste(jamId: jam.id)
            
            print("✅ Jam reposteado")
        }
    }
    
    // MARK: - Start Listening (Real-time)
    
    func startListening() {
        guard let myId = currentUserId else { return }
        
        Task {
            do {
                let snapshot = try await db.collection("users")
                    .document(myId)
                    .collection("following")
                    .getDocuments()
                
                let ids = snapshot.documents.map { $0.documentID }
                self.followingIds = ids
                self.setupRealtimeListener()
            } catch {
                print("❌ Error obteniendo following: \(error)")
            }
        }
    }
    
    private func setupRealtimeListener() {
        repostsListener?.remove()
        guard !followingIds.isEmpty else { return }
        
        let cutoffDate = Date().addingTimeInterval(-expirationTime)
        
        for batch in followingIds.chunked(into: 10) {
            repostsListener = db.collection("jamReposts")
                .whereField("userId", in: batch)
                .whereField("repostedAt", isGreaterThan: Timestamp(date: cutoffDate))
                .order(by: "repostedAt", descending: true)
                .limit(to: 20)
                .addSnapshotListener { [weak self] snapshot, error in
                    guard let self = self, let snapshot = snapshot else { return }
                    
                    for change in snapshot.documentChanges where change.type == .added {
                        if let repost = JamRepost.from(change.document.data()) {
                            self.handleNewRepost(repost)
                        }
                    }
                }
        }
        
        print("🔴 Listener de jam reposts iniciado")
    }
    
    private func handleNewRepost(_ repost: JamRepost) {
        // No mostrar mis propios reposts en el feed
        if repost.userId == currentUserId { return }
        // No mostrar si ya lo vi
        if seenRepostIds.contains(repost.id) { return }
        // No mostrar si ya está en pendientes
        if pendingReposts.contains(where: { $0.id == repost.id }) { return }
        // No mostrar si expiró
        if repost.isExpired { return }
        // Solo de amigos que sigo
        if !followingIds.contains(repost.userId) { return }
        
        print("🆕 Nuevo jam repost detectado: \(repost.jamTitle) por @\(repost.username)")
        
        DispatchQueue.main.async {
            self.pendingReposts.insert(repost, at: 0)
        }
    }
    
    func getNextPendingRepost() -> JamRepost? {
        pendingReposts.removeAll { $0.isExpired }
        
        guard !pendingReposts.isEmpty else { return nil }
        let repost = pendingReposts.removeFirst()
        markAsSeen(repostId: repost.id)
        return repost
    }
    
    // MARK: - Fetch Initial Reposts
    
    func fetchInitialReposts() async -> [JamRepost] {
        guard let myId = currentUserId else { return [] }
        
        isLoading = true
        
        do {
            if followingIds.isEmpty {
                let snapshot = try await db.collection("users")
                    .document(myId)
                    .collection("following")
                    .getDocuments()
                followingIds = snapshot.documents.map { $0.documentID }
            }
            
            guard !followingIds.isEmpty else {
                isLoading = false
                return []
            }
            
            var allReposts: [JamRepost] = []
            var addedIds: Set<String> = []
            let cutoffDate = Date().addingTimeInterval(-expirationTime)
            
            for batch in followingIds.chunked(into: 10) {
                let snapshot = try await db.collection("jamReposts")
                    .whereField("userId", in: batch)
                    .whereField("repostedAt", isGreaterThan: Timestamp(date: cutoffDate))
                    .order(by: "repostedAt", descending: true)
                    .limit(to: 30)
                    .getDocuments()
                
                for doc in snapshot.documents {
                    if let repost = JamRepost.from(doc.data()) {
                        // No mis reposts
                        if repost.userId == myId { continue }
                        // No vistos
                        if seenRepostIds.contains(repost.id) { continue }
                        // No duplicados
                        if addedIds.contains(repost.id) { continue }
                        // No expirados
                        if repost.isExpired { continue }
                        // Solo de amigos
                        if !followingIds.contains(repost.userId) { continue }
                        
                        allReposts.append(repost)
                        addedIds.insert(repost.id)
                    }
                }
            }
            
            allReposts.sort { $0.repostedAt > $1.repostedAt }
            
            isLoading = false
            print("📥 \(allReposts.count) jam reposts cargados")
            return Array(allReposts.prefix(15))
            
        } catch {
            print("❌ Error cargando reposts: \(error)")
            isLoading = false
            return []
        }
    }
    
    // MARK: - Fetch Reposts for Jam (solo de amigos, no míos)
    
    func fetchRepostsForJam(_ jamId: String) async -> [JamRepost] {
        guard let myId = currentUserId else { return [] }
        
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
        
        do {
            let snapshot = try await db.collection("jamReposts")
                .whereField("jamId", isEqualTo: jamId)
                .limit(to: 20)
                .getDocuments()
            
            var reposts: [JamRepost] = []
            for doc in snapshot.documents {
                if let repost = JamRepost.from(doc.data()) {
                    // NO mostrar MIS reposts en burbujas
                    if repost.userId == myId { continue }
                    // No expirados
                    if repost.isExpired { continue }
                    // SOLO de amigos que sigo
                    if !followingIds.contains(repost.userId) { continue }
                    
                    reposts.append(repost)
                }
            }
            
            reposts.sort { $0.repostedAt > $1.repostedAt }
            return Array(reposts.prefix(5))
            
        } catch {
            print("❌ Error fetching reposts for jam: \(error)")
            return []
        }
    }
    
    // MARK: - Fetch My Reposts
    
    func fetchMyReposts() async {
        guard let userId = currentUserId else { return }
        
        do {
            let snapshot = try await db.collection("users")
                .document(userId)
                .collection("jamReposts")
                .getDocuments()
            
            let ids = Set(snapshot.documents.map { $0.documentID })
            self.myRepostedJamIds = ids
            print("✅ Mis jam reposts: \(ids.count)")
        } catch {
            print("❌ Error cargando mis reposts: \(error)")
        }
    }
    
    // MARK: - Fetch Repost Count
    
    func fetchRepostCount(for jamId: String) async {
        do {
            let snapshot = try await db.collection("jamReposts")
                .whereField("jamId", isEqualTo: jamId)
                .getDocuments()
            
            self.repostCounts[jamId] = snapshot.documents.count
            repostCountsDidChange.send()
            objectWillChange.send()
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
    
    // MARK: - Convert to VisibleJamRepost
    
    func toVisibleRepost(_ repost: JamRepost) -> VisibleJamRepost {
        let colors: [Color] = [.green, .pink, .yellow, .orange, .cyan, .purple, .mint]
        let randomColor = colors.randomElement() ?? .green
        
        return VisibleJamRepost(
            id: repost.id,
            jamId: repost.jamId,
            username: repost.username,
            profileUrl: repost.userProfileUrl,
            jamTitle: repost.jamTitle,
            comment: repost.comment,
            color: randomColor,
            repostedAt: repost.repostedAt
        )
    }
    
    // MARK: - Stop & Reset
    
    func stopListening() {
        repostsListener?.remove()
        repostsListener = nil
    }
    
    func resetOnLogout() {
        stopListening()
        pendingReposts = []
        myRepostedJamIds = []
        repostCounts = [:]
        followingIds = []
    }
}
