//
//  NotificationService.swift
//  Splash Screen
//
//  Created by Alexis Horteales Espinosa on 21/01/26.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

class NotificationService: ObservableObject {
    static let shared = NotificationService()
    
    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    
    @Published var notifications: [JamNotification] = []
    @Published var unreadCount: Int = 0
    @Published var isLoading = false
    private var unreadListener: ListenerRegistration?
    
    private init() {}
    
    private var currentUserId: String? {
        Auth.auth().currentUser?.uid
    }
    
    // MARK: - Fetch Notifications
    
    func fetchNotifications() async {
        guard let userId = currentUserId else { return }
        
        await MainActor.run { self.isLoading = true }
        
        do {
            let snapshot = try await db.collection("notifications")
                .whereField("toUserId", isEqualTo: userId)
                .order(by: "createdAt", descending: true)
                .limit(to: 50)
                .getDocuments()
            
            let notifs = snapshot.documents.map { doc in
                JamNotification(from: doc.data(), documentId: doc.documentID)
            }
            
            await MainActor.run {
                self.notifications = notifs
                self.unreadCount = notifs.filter { !$0.isRead }.count
                self.isLoading = false
            }
        } catch {
            await MainActor.run { self.isLoading = false }
        }
    }
    
    // MARK: - Start Listening (Real-time updates)
    
    func startListening() {
        guard let userId = currentUserId else { return }
        
        listener?.remove()
        
        listener = db.collection("notifications")
            .whereField("toUserId", isEqualTo: userId)
            .order(by: "createdAt", descending: true)
            .limit(to: 50)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self, let snapshot = snapshot else { return }
                
                let notifs = snapshot.documents.map { doc in
                    JamNotification(from: doc.data(), documentId: doc.documentID)
                }
                
                DispatchQueue.main.async {
                    self.notifications = notifs
                    self.unreadCount = notifs.filter { !$0.isRead }.count
                }
            }
    }
    
    // MARK: - ✅ Start Listening to Unread Count
        
        func startListeningToUnreadCount() {
            guard let userId = currentUserId else { return }
            
            // Detener listener anterior si existe
            unreadListener?.remove()
            
            print("🎧 Iniciando listener de notificaciones no leídas para: \(userId)")
            
            // ✅ Escuchar SOLO notificaciones NO leídas
            unreadListener = db.collection("notifications")
                .whereField("toUserId", isEqualTo: userId)
                .whereField("isRead", isEqualTo: false)
                .addSnapshotListener { [weak self] snapshot, error in
                    guard let self = self else { return }
                    
                    if let error = error {
                        print("❌ Error en listener de no leídas: \(error)")
                        return
                    }
                    
                    guard let documents = snapshot?.documents else {
                        print("⚠️ No hay documentos en snapshot")
                        return
                    }
                    
                    DispatchQueue.main.async {
                        self.unreadCount = documents.count
                        print("🔔 Notificaciones no leídas: \(documents.count)")
                    }
                }
        }
    
    func stopListening() {
            listener?.remove()
            listener = nil
            unreadListener?.remove()
            unreadListener = nil
        }
    
    // MARK: - Mark as Read
    func markAsRead(_ notificationId: String) async {
          do {
              try await db.collection("notifications")
                  .document(notificationId)
                  .updateData(["isRead": true])
              
              await MainActor.run {
                  if let index = self.notifications.firstIndex(where: { $0.id == notificationId }) {
                      self.notifications[index].isRead = true
                  }
              }
              
              print("✅ Notificación \(notificationId) marcada como leída")
          } catch {
              print("❌ Error marcando como leída: \(error)")
          }
      }
    
    func markAllAsRead() async {
           guard let userId = currentUserId else { return }
           
           do {
               let snapshot = try await db.collection("notifications")
                   .whereField("toUserId", isEqualTo: userId)
                   .whereField("isRead", isEqualTo: false)
                   .getDocuments()
               
               guard !snapshot.documents.isEmpty else {
                   print("ℹ️ No hay notificaciones para marcar como leídas")
                   return
               }
               
               print("📝 Marcando \(snapshot.documents.count) notificaciones como leídas")
               
               let batch = db.batch()
               for doc in snapshot.documents {
                   batch.updateData(["isRead": true], forDocument: doc.reference)
               }
               try await batch.commit()
               
               await MainActor.run {
                   for i in self.notifications.indices {
                       self.notifications[i].isRead = true
                   }
               }
               
               print("✅ Todas las notificaciones marcadas como leídas")
           } catch {
               print("❌ Error marcando todas como leídas: \(error)")
           }
       }
    // MARK: - Send Notifications (Audius Tracks)
    
    /// Enviar notificación de like a un repost
    func sendLikeNotification(
        toUserId: String,
        fromUser: User,
        track: AudiusTrack
    ) async {
        guard let currentUserId = currentUserId else { return }
        guard toUserId != currentUserId else { return }
        
        let existingNotif = try? await db.collection("notifications")
            .whereField("type", isEqualTo: NotificationType.like.rawValue)
            .whereField("fromUserId", isEqualTo: currentUserId)
            .whereField("toUserId", isEqualTo: toUserId)
            .whereField("trackId", isEqualTo: track.id)
            .getDocuments()
        
        if existingNotif?.documents.isEmpty == false { return }
        
        let notification = JamNotification(
            type: .like,
            fromUserId: currentUserId,
            fromUsername: fromUser.username,
            fromUserProfileUrl: fromUser.profileImageUrl,
            toUserId: toUserId,
            trackId: track.id,
            trackTitle: track.title,
            trackImageUrl: track.imageURL
        )
        
        try? await db.collection("notifications")
            .addDocument(data: notification.toDictionary())
    }
    
    /// Enviar notificación de repost
    func sendRepostNotification(
        toUserId: String,
        fromUser: User,
        track: AudiusTrack
    ) async {
        guard let currentUserId = currentUserId else { return }
        guard toUserId != currentUserId else { return }
        
        let existingNotif = try? await db.collection("notifications")
            .whereField("type", isEqualTo: NotificationType.repost.rawValue)
            .whereField("fromUserId", isEqualTo: currentUserId)
            .whereField("toUserId", isEqualTo: toUserId)
            .whereField("trackId", isEqualTo: track.id)
            .getDocuments()
        
        if existingNotif?.documents.isEmpty == false { return }
        
        let notification = JamNotification(
            type: .repost,
            fromUserId: currentUserId,
            fromUsername: fromUser.username,
            fromUserProfileUrl: fromUser.profileImageUrl,
            toUserId: toUserId,
            trackId: track.id,
            trackTitle: track.title,
            trackImageUrl: track.imageURL
        )
        
        try? await db.collection("notifications")
            .addDocument(data: notification.toDictionary())
    }
    
    /// Enviar notificación de follow
    func sendFollowNotification(
        toUserId: String,
        fromUser: User
    ) async {
        guard let currentUserId = currentUserId else { return }
        guard toUserId != currentUserId else { return }
        
        let existingNotif = try? await db.collection("notifications")
            .whereField("type", isEqualTo: NotificationType.follow.rawValue)
            .whereField("fromUserId", isEqualTo: currentUserId)
            .whereField("toUserId", isEqualTo: toUserId)
            .getDocuments()
        
        if existingNotif?.documents.isEmpty == false { return }
        
        let notification = JamNotification(
            type: .follow,
            fromUserId: currentUserId,
            fromUsername: fromUser.username,
            fromUserProfileUrl: fromUser.profileImageUrl,
            toUserId: toUserId
        )
        
        try? await db.collection("notifications")
            .addDocument(data: notification.toDictionary())
    }
    
    /// Enviar notificación a seguidores cuando haces un repost (Audius)
    func sendFriendRepostNotification(
        fromUser: User,
        track: AudiusTrack
    ) async {
        guard let currentUserId = currentUserId else { return }
        
        do {
            let followersSnapshot = try await db.collection("users")
                .document(currentUserId)
                .collection("followers")
                .getDocuments()
            
            let followerIds = followersSnapshot.documents.map { $0.documentID }
            
            for followerId in followerIds {
                guard followerId != currentUserId else { continue }
                
                let existingNotif = try? await db.collection("notifications")
                    .whereField("type", isEqualTo: NotificationType.friendRepost.rawValue)
                    .whereField("fromUserId", isEqualTo: currentUserId)
                    .whereField("toUserId", isEqualTo: followerId)
                    .whereField("trackId", isEqualTo: track.id)
                    .getDocuments()
                
                if existingNotif?.documents.isEmpty == false { continue }
                
                let notification = JamNotification(
                    type: .friendRepost,
                    fromUserId: currentUserId,
                    fromUsername: fromUser.username,
                    fromUserProfileUrl: fromUser.profileImageUrl,
                    toUserId: followerId,
                    trackId: track.id,
                    trackTitle: track.title,
                    trackImageUrl: track.imageURL
                )
                
                try? await db.collection("notifications")
                    .addDocument(data: notification.toDictionary())
            }
        } catch {}
    }
    
    // MARK: - Send Notifications (Jam Premium)
    
    /// Enviar notificación de repost de Jam Premium al dueño
    func sendJamRepostNotification(
        toUserId: String,
        fromUser: User,
        jam: Jam
    ) async {
        guard let currentUserId = currentUserId else { return }
        guard toUserId != currentUserId else { return }
        
        let existingNotif = try? await db.collection("notifications")
            .whereField("type", isEqualTo: NotificationType.repost.rawValue)
            .whereField("fromUserId", isEqualTo: currentUserId)
            .whereField("toUserId", isEqualTo: toUserId)
            .whereField("trackId", isEqualTo: jam.id)
            .getDocuments()
        
        if existingNotif?.documents.isEmpty == false { return }
        
        let notification = JamNotification(
            type: .repost,
            fromUserId: currentUserId,
            fromUsername: fromUser.username,
            fromUserProfileUrl: fromUser.profileImageUrl,
            toUserId: toUserId,
            trackId: jam.id,
            trackTitle: jam.title,
            trackImageUrl: jam.artworkUrl
        )
        
        try? await db.collection("notifications")
            .addDocument(data: notification.toDictionary())
        
        print("📬 Notificación de repost enviada a \(toUserId)")
    }
    
    /// Enviar notificación a seguidores cuando reposteas un Jam Premium
    func sendFriendJamRepostNotification(
        fromUser: User,
        jam: Jam
    ) async {
        guard let currentUserId = currentUserId else { return }
        
        do {
            let followersSnapshot = try await db.collection("users")
                .document(currentUserId)
                .collection("followers")
                .getDocuments()
            
            let followerIds = followersSnapshot.documents.map { $0.documentID }
            
            print("📤 Enviando notificaciones a \(followerIds.count) seguidores")
            
            for followerId in followerIds {
                guard followerId != currentUserId else { continue }
                
                // Evitar duplicados
                let existingNotif = try? await db.collection("notifications")
                    .whereField("type", isEqualTo: NotificationType.friendRepost.rawValue)
                    .whereField("fromUserId", isEqualTo: currentUserId)
                    .whereField("toUserId", isEqualTo: followerId)
                    .whereField("trackId", isEqualTo: jam.id)
                    .getDocuments()
                
                if existingNotif?.documents.isEmpty == false { continue }
                
                let notification = JamNotification(
                    type: .friendRepost,
                    fromUserId: currentUserId,
                    fromUsername: fromUser.username,
                    fromUserProfileUrl: fromUser.profileImageUrl,
                    toUserId: followerId,
                    trackId: jam.id,
                    trackTitle: jam.title,
                    trackImageUrl: jam.artworkUrl
                )
                
                try? await db.collection("notifications")
                    .addDocument(data: notification.toDictionary())
            }
            
        } catch {
            print("❌ Error enviando notificaciones: \(error)")
        }
    }
    
    /// Enviar notificación de like a un Jam Premium
    func sendJamLikeNotification(
        toUserId: String,
        fromUser: User,
        jam: Jam
    ) async {
        guard let currentUserId = currentUserId else { return }
        guard toUserId != currentUserId else { return }
        
        let existingNotif = try? await db.collection("notifications")
            .whereField("type", isEqualTo: NotificationType.like.rawValue)
            .whereField("fromUserId", isEqualTo: currentUserId)
            .whereField("toUserId", isEqualTo: toUserId)
            .whereField("trackId", isEqualTo: jam.id)
            .getDocuments()
        
        if existingNotif?.documents.isEmpty == false { return }
        
        let notification = JamNotification(
            type: .like,
            fromUserId: currentUserId,
            fromUsername: fromUser.username,
            fromUserProfileUrl: fromUser.profileImageUrl,
            toUserId: toUserId,
            trackId: jam.id,
            trackTitle: jam.title,
            trackImageUrl: jam.artworkUrl
        )
        
        try? await db.collection("notifications")
            .addDocument(data: notification.toDictionary())
        
        print("📬 Notificación de like enviada a \(toUserId)")
    }
    
    // MARK: - Delete Notifications
    
    func deleteLikeNotification(toUserId: String, trackId: String) async {
        guard let currentUserId = currentUserId else { return }
        
        do {
            let snapshot = try await db.collection("notifications")
                .whereField("type", isEqualTo: NotificationType.like.rawValue)
                .whereField("fromUserId", isEqualTo: currentUserId)
                .whereField("toUserId", isEqualTo: toUserId)
                .whereField("trackId", isEqualTo: trackId)
                .getDocuments()
            
            for doc in snapshot.documents {
                try await doc.reference.delete()
            }
        } catch {}
    }
    
    func deleteFollowNotification(toUserId: String) async {
        guard let currentUserId = currentUserId else { return }
        
        do {
            let snapshot = try await db.collection("notifications")
                .whereField("type", isEqualTo: NotificationType.follow.rawValue)
                .whereField("fromUserId", isEqualTo: currentUserId)
                .whereField("toUserId", isEqualTo: toUserId)
                .getDocuments()
            
            for doc in snapshot.documents {
                try await doc.reference.delete()
            }
        } catch {}
    }
    
    func deleteFriendRepostNotifications(trackId: String) async {
        guard let currentUserId = currentUserId else { return }
        
        do {
            let snapshot = try await db.collection("notifications")
                .whereField("type", isEqualTo: NotificationType.friendRepost.rawValue)
                .whereField("fromUserId", isEqualTo: currentUserId)
                .whereField("trackId", isEqualTo: trackId)
                .getDocuments()
            
            for doc in snapshot.documents {
                try await doc.reference.delete()
            }
        } catch {}
    }
    
    /// Eliminar notificaciones de repost de Jam Premium
    func deleteJamRepostNotifications(jamId: String) async {
        guard let currentUserId = currentUserId else { return }
        
        do {
            // Eliminar notificación al dueño
            let repostSnapshot = try await db.collection("notifications")
                .whereField("type", isEqualTo: NotificationType.repost.rawValue)
                .whereField("fromUserId", isEqualTo: currentUserId)
                .whereField("trackId", isEqualTo: jamId)
                .getDocuments()
            
            for doc in repostSnapshot.documents {
                try await doc.reference.delete()
            }
            
            // Eliminar notificaciones a seguidores
            let friendSnapshot = try await db.collection("notifications")
                .whereField("type", isEqualTo: NotificationType.friendRepost.rawValue)
                .whereField("fromUserId", isEqualTo: currentUserId)
                .whereField("trackId", isEqualTo: jamId)
                .getDocuments()
            
            for doc in friendSnapshot.documents {
                try await doc.reference.delete()
            }
            
            print("🗑️ Notificaciones de jam repost eliminadas")
        } catch {
            print("❌ Error eliminando notificaciones: \(error)")
        }
    }
    
    // MARK: - Reset
    
    func resetOnLogout() {
        stopListening()
        notifications = []
        unreadCount = 0
    }
}
