//
//  JamNotification.swift
//  Splash Screen
//
//  Created by Alexis Horteales Espinosa on 31/01/26.
//


import Foundation
import FirebaseFirestore

enum NotificationType: String, Codable {
    case like = "like"
    case repost = "repost"
    case follow = "follow"
    case friendRepost = "friendRepost"  // Cuando un amigo hace repost
}

struct JamNotification: Identifiable, Codable {
    @DocumentID var id: String?
    let type: NotificationType
    let fromUserId: String
    let fromUsername: String
    let fromUserProfileUrl: String?
    let toUserId: String
    let createdAt: Date
    
    // Solo para likes, reposts y friendRepost
    let trackId: String?
    let trackTitle: String?
    let trackImageUrl: String?
    
    // Para saber si ya lo leímos
    var isRead: Bool
    
    // Computed properties
    var notificationId: String {
        id ?? UUID().uuidString
    }
    
    var isToday: Bool {
        Calendar.current.isDateInToday(createdAt)
    }
    
    var isYesterday: Bool {
        Calendar.current.isDateInYesterday(createdAt)
    }
    
    var timeAgo: String {
        let now = Date()
        let components = Calendar.current.dateComponents([.minute, .hour, .day, .weekOfYear], from: createdAt, to: now)
        
        if let weeks = components.weekOfYear, weeks > 0 {
            return "\(weeks)w"
        } else if let days = components.day, days > 0 {
            return "\(days)d"
        } else if let hours = components.hour, hours > 0 {
            return "\(hours)h"
        } else if let minutes = components.minute, minutes > 0 {
            return "\(minutes)m"
        } else {
            return "now"
        }
    }
    
    // Para crear desde diccionario de Firebase
    init(from data: [String: Any], documentId: String) {
        self.id = documentId
        self.type = NotificationType(rawValue: data["type"] as? String ?? "like") ?? .like
        self.fromUserId = data["fromUserId"] as? String ?? ""
        self.fromUsername = data["fromUsername"] as? String ?? ""
        self.fromUserProfileUrl = data["fromUserProfileUrl"] as? String
        self.toUserId = data["toUserId"] as? String ?? ""
        self.createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        self.trackId = data["trackId"] as? String
        self.trackTitle = data["trackTitle"] as? String
        self.trackImageUrl = data["trackImageUrl"] as? String
        self.isRead = data["isRead"] as? Bool ?? false
    }
    
    // Para crear manualmente
    init(
        id: String? = nil,
        type: NotificationType,
        fromUserId: String,
        fromUsername: String,
        fromUserProfileUrl: String?,
        toUserId: String,
        createdAt: Date = Date(),
        trackId: String? = nil,
        trackTitle: String? = nil,
        trackImageUrl: String? = nil,
        isRead: Bool = false
    ) {
        self.id = id
        self.type = type
        self.fromUserId = fromUserId
        self.fromUsername = fromUsername
        self.fromUserProfileUrl = fromUserProfileUrl
        self.toUserId = toUserId
        self.createdAt = createdAt
        self.trackId = trackId
        self.trackTitle = trackTitle
        self.trackImageUrl = trackImageUrl
        self.isRead = isRead
    }
    
    // Convertir a diccionario para Firebase
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "type": type.rawValue,
            "fromUserId": fromUserId,
            "fromUsername": fromUsername,
            "toUserId": toUserId,
            "createdAt": Timestamp(date: createdAt),
            "isRead": isRead
        ]
        
        if let url = fromUserProfileUrl {
            dict["fromUserProfileUrl"] = url
        }
        if let trackId = trackId {
            dict["trackId"] = trackId
        }
        if let trackTitle = trackTitle {
            dict["trackTitle"] = trackTitle
        }
        if let trackImageUrl = trackImageUrl {
            dict["trackImageUrl"] = trackImageUrl
        }
        
        return dict
    }
}
