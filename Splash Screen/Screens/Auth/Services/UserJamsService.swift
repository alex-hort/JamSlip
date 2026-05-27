//
//  UserJamsService.swift
//  Splash Screen
//
//  Created by Alexis Horteales Espinosa on 14/01/26.
//
import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

class UserJamsService: ObservableObject {
    static let shared = UserJamsService()
    
    private let db = Firestore.firestore()
    
    @Published var likedTracks: [AudiusTrack] = []
    @Published var savedTracks: [AudiusTrack] = []
    
    private var likedTrackIds: Set<String> = []
    private var savedTrackIds: Set<String> = []
    
    @Published var globalLikesCount: [String: Int] = [:]
    @Published var globalSavesCount: [String: Int] = [:]
    
    private var cachedUserId: String?
    
    private init() {}
    
    private var currentUserId: String? { Auth.auth().currentUser?.uid }
    
    private func checkUserChanged() {
        let newUserId = currentUserId
        if cachedUserId != newUserId {
            likedTracks = []
            savedTracks = []
            likedTrackIds = []
            savedTrackIds = []
            cachedUserId = newUserId
        }
    }
    
    func getLikesCount(for trackId: String) -> Int {
        max(0, globalLikesCount[trackId] ?? 0)
    }
    
    func getSavesCount(for trackId: String) -> Int {
        max(0, globalSavesCount[trackId] ?? 0)
    }
    
    func isLiked(_ track: AudiusTrack) -> Bool {
        checkUserChanged()
        return likedTrackIds.contains(track.id)
    }
    
    func isSaved(_ track: AudiusTrack) -> Bool {
        checkUserChanged()
        return savedTrackIds.contains(track.id)
    }
    
    func optimisticToggleLike(_ track: AudiusTrack) {
        checkUserChanged()
        
        if likedTrackIds.contains(track.id) {
            likedTrackIds.remove(track.id)
            likedTracks.removeAll { $0.id == track.id }
            globalLikesCount[track.id] = max(0, (globalLikesCount[track.id] ?? 1) - 1)
        } else {
            likedTrackIds.insert(track.id)
            likedTracks.insert(track, at: 0)
            globalLikesCount[track.id] = (globalLikesCount[track.id] ?? 0) + 1
        }
    }
    
    func optimisticToggleSave(_ track: AudiusTrack) {
        checkUserChanged()
        
        if savedTrackIds.contains(track.id) {
            savedTrackIds.remove(track.id)
            savedTracks.removeAll { $0.id == track.id }
            globalSavesCount[track.id] = max(0, (globalSavesCount[track.id] ?? 1) - 1)
        } else {
            savedTrackIds.insert(track.id)
            savedTracks.insert(track, at: 0)
            globalSavesCount[track.id] = (globalSavesCount[track.id] ?? 0) + 1
        }
    }
    
    func syncLikeToFirebase(_ track: AudiusTrack, wasLiked: Bool) async throws {
        guard let userId = currentUserId else { return }
        
        let userLikeRef = db.collection("users").document(userId).collection("likedJams").document(track.id)
        let globalTrackRef = db.collection("jams").document(track.id)
        
        if wasLiked {
            try await userLikeRef.delete()
            try await globalTrackRef.updateData(["likesCount": FieldValue.increment(Int64(-1))])
        } else {
            let trackData = encodeTrackForUser(track)
            try await userLikeRef.setData(trackData)
            try await globalTrackRef.setData([
                "likesCount": FieldValue.increment(Int64(1)),
                "trackInfo": encodeTrackInfo(track)
            ], merge: true)
        }
    }
    
    func syncSaveToFirebase(_ track: AudiusTrack, wasSaved: Bool) async throws {
        guard let userId = currentUserId else { return }
        
        let userSaveRef = db.collection("users").document(userId).collection("savedJams").document(track.id)
        let globalTrackRef = db.collection("jams").document(track.id)
        
        if wasSaved {
            try await userSaveRef.delete()
            try await globalTrackRef.updateData(["savesCount": FieldValue.increment(Int64(-1))])
        } else {
            let trackData = encodeTrackForUser(track)
            try await userSaveRef.setData(trackData)
            try await globalTrackRef.setData([
                "savesCount": FieldValue.increment(Int64(1)),
                "trackInfo": encodeTrackInfo(track)
            ], merge: true)
        }
    }
    
    func toggleLike(_ track: AudiusTrack) async throws {
        let wasLiked = isLiked(track)
        await MainActor.run { optimisticToggleLike(track) }
        try await syncLikeToFirebase(track, wasLiked: wasLiked)
    }
    
    func toggleSave(_ track: AudiusTrack) async throws {
        let wasSaved = isSaved(track)
        await MainActor.run { optimisticToggleSave(track) }
        try await syncSaveToFirebase(track, wasSaved: wasSaved)
    }
    
    func fetchLikedTracks() async throws {
        guard let userId = currentUserId else { return }
        checkUserChanged()
        
        let snapshot = try await db.collection("users")
            .document(userId)
            .collection("likedJams")
            .order(by: "savedAt", descending: true)
            .getDocuments()
        
        let tracks = snapshot.documents.compactMap { decodeTrack(from: $0.data()) }
        let ids = Set(tracks.map { $0.id })
        
        await MainActor.run {
            self.likedTracks = tracks
            self.likedTrackIds = ids
        }
    }
    
    func fetchSavedTracks() async throws {
        guard let userId = currentUserId else { return }
        checkUserChanged()
        
        let snapshot = try await db.collection("users")
            .document(userId)
            .collection("savedJams")
            .order(by: "savedAt", descending: true)
            .getDocuments()
        
        let tracks = snapshot.documents.compactMap { decodeTrack(from: $0.data()) }
        let ids = Set(tracks.map { $0.id })
        
        await MainActor.run {
            self.savedTracks = tracks
            self.savedTrackIds = ids
        }
    }
    
    func fetchLikedTracks(for userId: String) async throws -> [AudiusTrack] {
        let snapshot = try await db.collection("users")
            .document(userId)
            .collection("likedJams")
            .order(by: "savedAt", descending: true)
            .getDocuments()
        return snapshot.documents.compactMap { decodeTrack(from: $0.data()) }
    }
    
    func fetchSavedTracks(for userId: String) async throws -> [AudiusTrack] {
        let snapshot = try await db.collection("users")
            .document(userId)
            .collection("savedJams")
            .order(by: "savedAt", descending: true)
            .getDocuments()
        return snapshot.documents.compactMap { decodeTrack(from: $0.data()) }
    }
    
    func fetchGlobalCounts(for trackId: String) async {
        do {
            let doc = try await db.collection("jams").document(trackId).getDocument()
            if let data = doc.data() {
                let likes = max(0, data["likesCount"] as? Int ?? 0)
                let saves = max(0, data["savesCount"] as? Int ?? 0)
                await MainActor.run {
                    self.globalLikesCount[trackId] = likes
                    self.globalSavesCount[trackId] = saves
                }
            }
        } catch {}
    }
    
    func fetchAllUserJams() async {
        checkUserChanged()
        do {
            try await fetchLikedTracks()
            try await fetchSavedTracks()
        } catch {}
    }
    
    private func encodeTrackForUser(_ track: AudiusTrack) -> [String: Any] {
        var data: [String: Any] = [
            "id": track.id,
            "title": track.title,
            "duration": track.duration,
            "userName": track.user.name,
            "userHandle": track.user.handle,
            "savedAt": FieldValue.serverTimestamp()
        ]
        if let imageURL = track.imageURL { data["imageURL"] = imageURL }
        if let profilePic = track.user.profilePicture { data["userProfilePicture"] = profilePic }
        return data
    }
    
    private func encodeTrackInfo(_ track: AudiusTrack) -> [String: Any] {
        var data: [String: Any] = [
            "id": track.id,
            "title": track.title,
            "duration": track.duration,
            "userName": track.user.name,
            "userHandle": track.user.handle
        ]
        if let imageURL = track.imageURL { data["imageURL"] = imageURL }
        if let profilePic = track.user.profilePicture { data["userProfilePicture"] = profilePic }
        return data
    }
    
    private func decodeTrack(from data: [String: Any]) -> AudiusTrack? {
        guard let id = data["id"] as? String,
              let title = data["title"] as? String,
              let duration = data["duration"] as? Int,
              let userName = data["userName"] as? String,
              let userHandle = data["userHandle"] as? String else { return nil }
        
        let imageURL = data["imageURL"] as? String
        let userProfilePicture = data["userProfilePicture"] as? String
        var artwork: Artwork? = nil
        if let url = imageURL { artwork = Artwork(small: url, medium: url, large: url) }
        
        return AudiusTrack(
            id: id, title: title, duration: duration,
            artwork: artwork, coverPhoto: nil,
            user: AudiusUser(name: userName, handle: userHandle, profilePicture: userProfilePicture),
            playCount: nil, favoriteCount: nil
        )
    }
    
    func resetOnLogout() {
        likedTracks = []
        savedTracks = []
        likedTrackIds = []
        savedTrackIds = []
        globalLikesCount = [:]
        globalSavesCount = [:]
        cachedUserId = nil
    }
}

