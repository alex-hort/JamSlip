//
//  JamRepost.swift
//  Splash Screen
//
//  Created by Alexis Horteales Espinosa on 28/01/26.
//

import Foundation
import FirebaseFirestore
import SwiftUI

// MARK: - Jam Repost Model
struct JamRepost: Identifiable, Codable, Equatable {
    var id: String { "\(userId)_\(jamId)" }
    let jamId: String
    let odei: String // odei del jam original
    let originalUsername: String
    
    // Quien hizo el repost
    let userId: String
    let username: String
    let userProfileUrl: String?
    
    // Datos del jam
    let jamTitle: String
    let jamArtworkUrl: String?
    let jamAudioUrl: String
    let jamDuration: Int
    let jamGenre: String
    let jamMoods: [String]
    
    let repostedAt: Date
    var comment: String?
    
    // Para expiración (24 horas)
    var isExpired: Bool {
        Date().timeIntervalSince(repostedAt) > 86400 // 24 horas
    }
    
    var timeAgo: String {
        let interval = Date().timeIntervalSince(repostedAt)
        
        if interval < 60 {
            return "now"
        } else if interval < 3600 {
            return "\(Int(interval / 60))m"
        } else if interval < 86400 {
            return "\(Int(interval / 3600))h"
        } else {
            return "\(Int(interval / 86400))d"
        }
    }
    
    static func == (lhs: JamRepost, rhs: JamRepost) -> Bool {
        lhs.id == rhs.id
    }
    
    // Convertir a diccionario para Firebase
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "jamId": jamId,
            "odei": odei,
            "originalUsername": originalUsername,
            "userId": userId,
            "username": username,
            "jamTitle": jamTitle,
            "jamAudioUrl": jamAudioUrl,
            "jamDuration": jamDuration,
            "jamGenre": jamGenre,
            "jamMoods": jamMoods,
            "repostedAt": Timestamp(date: repostedAt)
        ]
        
        if let url = userProfileUrl {
            dict["userProfileUrl"] = url
        }
        if let artwork = jamArtworkUrl {
            dict["jamArtworkUrl"] = artwork
        }
        if let comment = comment {
            dict["comment"] = comment
        }
        
        return dict
    }
    
    // Crear desde diccionario de Firebase
    static func from(_ data: [String: Any]) -> JamRepost? {
        guard let jamId = data["jamId"] as? String,
              let odei = data["odei"] as? String,
              let originalUsername = data["originalUsername"] as? String,
              let odei2 = data["userId"] as? String,
              let username = data["username"] as? String,
              let jamTitle = data["jamTitle"] as? String,
              let jamAudioUrl = data["jamAudioUrl"] as? String,
              let jamDuration = data["jamDuration"] as? Int,
              let jamGenre = data["jamGenre"] as? String else {
            return nil
        }
        
        let jamMoods = data["jamMoods"] as? [String] ?? []
        let repostedAt = (data["repostedAt"] as? Timestamp)?.dateValue() ?? Date()
        
        return JamRepost(
            jamId: jamId,
            odei: odei,
            originalUsername: originalUsername,
            userId: odei2,
            username: username,
            userProfileUrl: data["userProfileUrl"] as? String,
            jamTitle: jamTitle,
            jamArtworkUrl: data["jamArtworkUrl"] as? String,
            jamAudioUrl: jamAudioUrl,
            jamDuration: jamDuration,
            jamGenre: jamGenre,
            jamMoods: jamMoods,
            repostedAt: repostedAt,
            comment: data["comment"] as? String
        )
    }
    
    // Convertir a Jam para mostrar en el feed
    func toJam() -> Jam {
        Jam(
            id: jamId,
            userId: odei,
            username: originalUsername,
            userProfileImageUrl: nil, // Se cargará del jam original
            title: jamTitle,
            description: "",
            genre: jamGenre,
            moods: jamMoods,
            audioUrl: jamAudioUrl,
            artworkUrl: jamArtworkUrl,
            duration: jamDuration,
            createdAt: repostedAt,
            likesCount: 0,
            repostsCount: 0,
            savesCount: 0,
            playsCount: 0
        )
    }
}




// MARK: - Visible Jam Repost (para UI)
struct VisibleJamRepost: Identifiable {
    let id: String
    let jamId: String
    let username: String
    let profileUrl: String?
    let jamTitle: String
    var comment: String?
    let color: Color
    let repostedAt: Date
    
    var timeAgo: String {
        let interval = Date().timeIntervalSince(repostedAt)
        
        if interval < 60 {
            return "now"
        } else if interval < 3600 {
            return "\(Int(interval / 60))m"
        } else if interval < 86400 {
            return "\(Int(interval / 3600))h"
        } else {
            return "\(Int(interval / 86400))d"
        }
    }
}
