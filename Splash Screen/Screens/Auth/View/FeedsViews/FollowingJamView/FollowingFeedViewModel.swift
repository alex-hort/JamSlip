//
//  FollowingFeedViewModel.swift
//  Splash Screen
//
//  Created by Alexis Horteales Espinosa on 22/02/26.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import Combine

// MARK: - FollowingFeed ViewModel
@MainActor
final class FollowingFeedViewModel: ObservableObject {
    
    // ✅ Singleton para persistir entre navegaciones
    static let shared = FollowingFeedViewModel()
    
    // MARK: - Published
    @Published var followingJams: [Jam] = []
    @Published var isLoading = true
    
    // MARK: - Private
    private var listeners: [ListenerRegistration] = []
    private var hasLoaded = false
    private var allJams: [Jam] = []
    
    private init() {}
    
    // MARK: - Start Listening (solo si no hay datos)
    func startListeningIfNeeded() async {
        guard !hasLoaded else { return }
        await startListening()
    }
    
    // MARK: - Start Listening
    func startListening() async {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            isLoading = false
            return
        }
        
        isLoading = true
        allJams = []
        
        let db = Firestore.firestore()
        
        do {
            let followingSnapshot = try await db.collection("users")
                .document(currentUserId)
                .collection("following")
                .getDocuments()
            
            let followingIds = followingSnapshot.documents.map { $0.documentID }
            
            guard !followingIds.isEmpty else {
                followingJams = []
                isLoading = false
                return
            }
            
            stopListening()
            
            // ✅ Un listener por cada batch de 10
            for batch in followingIds.chunked(into: 10) {
                let batchSet = Set(batch)
                
                let listener = db.collection("jamsPremium")
                    .whereField("userId", in: batch)
                    .addSnapshotListener { [weak self] snapshot, error in
                        guard let self, let snapshot else { return }
                        
                        let newJams = snapshot.documents.compactMap { doc in
                            self.decodeJam(from: doc.data())
                        }
                        
                        // ✅ Remover jams anteriores de este batch y agregar los nuevos
                        self.allJams.removeAll { batchSet.contains($0.userId) }
                        self.allJams.append(contentsOf: newJams)
                        self.allJams.sort { $0.createdAt > $1.createdAt }
                        
                        self.followingJams = self.allJams
                        self.isLoading = false
                        self.hasLoaded = true
                    }
                
                listeners.append(listener)
            }
            
        } catch {
            print("❌ Error en FollowingFeedViewModel: \(error)")
            isLoading = false
        }
    }
    
    // MARK: - Stop Listening
    func stopListening() {
        listeners.forEach { $0.remove() }
        listeners = []
    }
    
    // MARK: - Refresh manual (pull to refresh)
    func refresh() async {
        hasLoaded = false
        allJams = []
        await startListening()
    }
    
    // MARK: - Reset (al cerrar sesión)
    func reset() {
        stopListening()
        followingJams = []
        allJams = []
        hasLoaded = false
        isLoading = true
    }
    
    // MARK: - Decode Jam
    private func decodeJam(from data: [String: Any]) -> Jam? {
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
    }
}
