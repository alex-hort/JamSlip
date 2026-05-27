//
//  FollowService.swift
//  Splash Screen
//
//  Created by Alexis Horteales Espinosa on 14/01/26.
//

import Combine
import Foundation
import FirebaseFirestore
import FirebaseAuth

class FollowService: ObservableObject {
    static let shared = FollowService()
    
    private let db = Firestore.firestore()
    
    @Published var followingIds: Set<String> = []
    @Published var followersList: [User] = []
    @Published var followingList: [User] = []
    @Published var isLoadingFollowers = false
    @Published var isLoadingFollowing = false
    @Published var followersCountCache: [String: Int] = [:]
    @Published var followingCountCache: [String: Int] = [:]
    
    private init() {}
    
    var currentUserId: String? {
        Auth.auth().currentUser?.uid
    }
    
    // MARK: - Get Counts
    func getFollowersCount(for userId: String) -> Int {
        max(0, followersCountCache[userId] ?? 0)
    }
    
    func getFollowingCount(for userId: String) -> Int {
        max(0, followingCountCache[userId] ?? 0)
    }
    
    // MARK: - Check if Following
    func isFollowing(_ userId: String) -> Bool {
        followingIds.contains(userId)
    }
    
    func checkIfFollowing(targetUserId: String) async -> Bool {
        guard let currentUserId = currentUserId else { return false }
        
        do {
            let doc = try await db.collection("users")
                .document(currentUserId)
                .collection("following")
                .document(targetUserId)
                .getDocument()
            
            let isFollowing = doc.exists
            
            await MainActor.run {
                if isFollowing {
                    self.followingIds.insert(targetUserId)
                } else {
                    self.followingIds.remove(targetUserId)
                }
            }
            
            return isFollowing
        } catch {
            return followingIds.contains(targetUserId)
        }
    }
    
    // MARK: - Load User Counts
    func loadUserCounts(userId: String) async {
        do {
            let followersSnapshot = try await db.collection("users")
                .document(userId)
                .collection("followers")
                .getDocuments()
            
            let followingSnapshot = try await db.collection("users")
                .document(userId)
                .collection("following")
                .getDocuments()
            
            let realFollowersCount = followersSnapshot.documents.count
            let realFollowingCount = followingSnapshot.documents.count
            
            await MainActor.run {
                self.followersCountCache[userId] = realFollowersCount
                self.followingCountCache[userId] = realFollowingCount
            }
        } catch {}
    }
    
    // MARK: - Fetch Followers List
    func fetchFollowers(for userId: String) async {
        await MainActor.run {
            self.isLoadingFollowers = true
            self.followersList = []
        }
        
        do {
            let snapshot = try await db.collection("users")
                .document(userId)
                .collection("followers")
                .getDocuments()
            
            let followerIds = snapshot.documents.map { $0.documentID }
            
            var users: [User] = []
            await withTaskGroup(of: User?.self) { group in
                for followerId in followerIds {
                    group.addTask {
                        let userDoc = try? await self.db.collection("users").document(followerId).getDocument()
                        return try? userDoc?.data(as: User.self)
                    }
                }
                
                for await user in group {
                    if let user = user {
                        users.append(user)
                    }
                }
            }
            
            await MainActor.run {
                self.followersList = users
                self.followersCountCache[userId] = users.count
                self.isLoadingFollowers = false
            }
            
        } catch {
            await MainActor.run {
                self.followersList = []
                self.isLoadingFollowers = false
            }
        }
    }
    
    // MARK: - Fetch Following List (Users)
    func fetchFollowingUsers(for userId: String) async {
        await MainActor.run {
            self.isLoadingFollowing = true
            self.followingList = []
        }
        
        do {
            let snapshot = try await db.collection("users")
                .document(userId)
                .collection("following")
                .getDocuments()
            
            let followingIdsList = snapshot.documents.map { $0.documentID }
            
            var users: [User] = []
            await withTaskGroup(of: User?.self) { group in
                for followingId in followingIdsList {
                    group.addTask {
                        let userDoc = try? await self.db.collection("users").document(followingId).getDocument()
                        return try? userDoc?.data(as: User.self)
                    }
                }
                
                for await user in group {
                    if let user = user {
                        users.append(user)
                    }
                }
            }
            
            await MainActor.run {
                self.followingList = users
                self.followingIds = Set(followingIdsList)
                self.followingCountCache[userId] = users.count
                self.isLoadingFollowing = false
            }
            
        } catch {
            await MainActor.run {
                self.followingList = []
                self.isLoadingFollowing = false
            }
        }
    }
    
    // MARK: - Follow (con UI optimista y notificación)
    func follow(targetUserId: String) async throws {
        guard let currentUserId = currentUserId else {
            throw NSError(domain: "FollowService", code: -1)
        }
        
        guard currentUserId != targetUserId else { return }
        if followingIds.contains(targetUserId) { return }
        
        // UI optimista
        await MainActor.run {
            self.followingIds.insert(targetUserId)
            self.followingCountCache[currentUserId] = (self.followingCountCache[currentUserId] ?? 0) + 1
            self.followersCountCache[targetUserId] = (self.followersCountCache[targetUserId] ?? 0) + 1
        }
        
        // Firebase
        let batch = db.batch()
        let timestamp = FieldValue.serverTimestamp()
        let followingRef = db.collection("users").document(currentUserId).collection("following").document(targetUserId)
        let followersRef = db.collection("users").document(targetUserId).collection("followers").document(currentUserId)
        
        batch.setData(["followedAt": timestamp], forDocument: followingRef)
        batch.setData(["followedAt": timestamp], forDocument: followersRef)
        
        try await batch.commit()
        
        // Notificación
        if let currentUserDoc = try? await db.collection("users").document(currentUserId).getDocument(),
           let currentUser = try? currentUserDoc.data(as: User.self) {
            await NotificationService.shared.sendFollowNotification(
                toUserId: targetUserId,
                fromUser: currentUser
            )
        }
    }
    
    // MARK: - Follow Silent (solo Firebase, sin UI optimista - ya se hizo antes)
    func followSilent(targetUserId: String) async throws {
        guard let currentUserId = currentUserId else {
            throw NSError(domain: "FollowService", code: -1)
        }
        
        guard currentUserId != targetUserId else { return }
        
        // Firebase
        let batch = db.batch()
        let timestamp = FieldValue.serverTimestamp()
        let followingRef = db.collection("users").document(currentUserId).collection("following").document(targetUserId)
        let followersRef = db.collection("users").document(targetUserId).collection("followers").document(currentUserId)
        
        batch.setData(["followedAt": timestamp], forDocument: followingRef)
        batch.setData(["followedAt": timestamp], forDocument: followersRef)
        
        try await batch.commit()
        
        // Notificación
        if let currentUserDoc = try? await db.collection("users").document(currentUserId).getDocument(),
           let currentUser = try? currentUserDoc.data(as: User.self) {
            await NotificationService.shared.sendFollowNotification(
                toUserId: targetUserId,
                fromUser: currentUser
            )
        }
    }
    
    // MARK: - Unfollow (con UI optimista)
    func unfollow(targetUserId: String) async throws {
        guard let currentUserId = currentUserId else {
            throw NSError(domain: "FollowService", code: -1)
        }
        
        // UI optimista
        await MainActor.run {
            self.followingIds.remove(targetUserId)
            self.followingList.removeAll { $0.uid == targetUserId }
            self.followingCountCache[currentUserId] = max(0, (self.followingCountCache[currentUserId] ?? 1) - 1)
            self.followersCountCache[targetUserId] = max(0, (self.followersCountCache[targetUserId] ?? 1) - 1)
        }
        
        // Firebase
        let batch = db.batch()
        let followingRef = db.collection("users").document(currentUserId).collection("following").document(targetUserId)
        let followersRef = db.collection("users").document(targetUserId).collection("followers").document(currentUserId)
        
        batch.deleteDocument(followingRef)
        batch.deleteDocument(followersRef)
        
        try await batch.commit()
        
        await NotificationService.shared.deleteFollowNotification(toUserId: targetUserId)
    }
    
    // MARK: - Unfollow Silent (solo Firebase, sin UI optimista)
    func unfollowSilent(targetUserId: String) async throws {
        guard let currentUserId = currentUserId else {
            throw NSError(domain: "FollowService", code: -1)
        }
        
        // Firebase
        let batch = db.batch()
        let followingRef = db.collection("users").document(currentUserId).collection("following").document(targetUserId)
        let followersRef = db.collection("users").document(targetUserId).collection("followers").document(currentUserId)
        
        batch.deleteDocument(followingRef)
        batch.deleteDocument(followersRef)
        
        try await batch.commit()
        
        await NotificationService.shared.deleteFollowNotification(toUserId: targetUserId)
    }
    
    // MARK: - Toggle Follow
    func toggleFollow(targetUserId: String) async throws {
        if isFollowing(targetUserId) {
            try await unfollow(targetUserId: targetUserId)
        } else {
            try await follow(targetUserId: targetUserId)
        }
    }
    
    // MARK: - Remove Follower
    func removeFollower(followerId: String) async throws {
        guard let currentUserId = currentUserId else {
            throw NSError(domain: "FollowService", code: -1)
        }
        
        await MainActor.run {
            self.followersList.removeAll { $0.uid == followerId }
            self.followersCountCache[currentUserId] = self.followersList.count
        }
        
        let batch = db.batch()
        let followerFollowingRef = db.collection("users").document(followerId).collection("following").document(currentUserId)
        let myFollowersRef = db.collection("users").document(currentUserId).collection("followers").document(followerId)
        
        batch.deleteDocument(followerFollowingRef)
        batch.deleteDocument(myFollowersRef)
        
        try await batch.commit()
        
        let newFollowingCount = max(0, (followingCountCache[followerId] ?? 1) - 1)
        await MainActor.run {
            self.followingCountCache[followerId] = newFollowingCount
        }
    }
    
    // MARK: - Fetch Following List (IDs only)
    func fetchFollowingList() async {
        guard let currentUserId = currentUserId else { return }
        
        do {
            let snapshot = try await db.collection("users")
                .document(currentUserId)
                .collection("following")
                .getDocuments()
            
            let ids = Set(snapshot.documents.map { $0.documentID })
            
            await MainActor.run {
                self.followingIds = ids
                self.followingCountCache[currentUserId] = ids.count
            }
            
            await loadUserCounts(userId: currentUserId)
            
        } catch {}
    }
    
    // MARK: - Reset
    func resetOnLogout() {
        followingIds = []
        followersList = []
        followingList = []
        followersCountCache = [:]
        followingCountCache = [:]
    }
}
