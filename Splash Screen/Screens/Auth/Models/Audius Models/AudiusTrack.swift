//
//  AudiusTrack.swift
//  Splash Screen
//
//  Created by Alexis Horteales Espinosa on 14/01/26.
//

import Foundation

// MARK: - Audius Models
struct AudiusTracksResponse: Codable {
    let data: [AudiusTrack]
}

struct AudiusTrack: Codable, Identifiable, Equatable {
    let id: String
    let title: String
    let duration: Int
    let artwork: Artwork?
    let coverPhoto: CoverPhoto?
    let user: AudiusUser
    let playCount: Int?
    let favoriteCount: Int?
    
    enum CodingKeys: String, CodingKey {
        case id, title, duration, artwork, user
        case coverPhoto = "cover_photo"
        case playCount = "play_count"
        case favoriteCount = "favorite_count"
    }
    
    var streamURL: URL {
        URL(string: "https://api.audius.co/v1/tracks/\(id)/stream")!
    }
    
    var imageURL: String? {
        artwork?.large ?? artwork?.medium ?? coverPhoto?.large
    }
    
    static func == (lhs: AudiusTrack, rhs: AudiusTrack) -> Bool {
        lhs.id == rhs.id
    }
    
    var likesCount: String {
        let likes = favoriteCount ?? 0
        
        if likes >= 1_000_000 {
            return String(format: "%.1fM", Double(likes) / 1_000_000)
        } else if likes >= 1_000 {
            return String(format: "%.1fK", Double(likes) / 1_000)
        } else {
            return "\(likes)"
        }
    }
}

struct Artwork: Codable {
    let small: String?
    let medium: String?
    let large: String?
    
    enum CodingKeys: String, CodingKey {
        case small = "150x150"
        case medium = "480x480"
        case large = "1000x1000"
    }
}

struct CoverPhoto: Codable {
    let small: String?
    let large: String?
    
    enum CodingKeys: String, CodingKey {
        case small = "640x"
        case large = "2000x"
    }
}

// MARK: - Audius User (con profile_picture)
struct AudiusUser: Codable {
    let name: String
    let handle: String
    var profilePicture: String?
    
    enum CodingKeys: String, CodingKey {
        case name
        case handle
        case profilePicture = "profile_picture"
    }
    
    init(name: String, handle: String, profilePicture: String? = nil) {
        self.name = name
        self.handle = handle
        self.profilePicture = profilePicture
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        handle = try container.decode(String.self, forKey: .handle)
        
        // profile_picture puede ser un objeto con tamaños o un string directo
        if let profileObj = try? container.decode(ProfilePictureSize.self, forKey: .profilePicture) {
            // Es un objeto con diferentes tamaños
            profilePicture = profileObj.medium ?? profileObj.small ?? profileObj.large
        } else if let profileStr = try? container.decode(String.self, forKey: .profilePicture) {
            // Es un string directo
            profilePicture = profileStr
        } else {
            profilePicture = nil
        }
    }
}

// Para decodificar cuando profile_picture viene como objeto
struct ProfilePictureSize: Codable {
    let small: String?
    let medium: String?
    let large: String?
    
    enum CodingKeys: String, CodingKey {
        case small = "150x150"
        case medium = "480x480"
        case large = "1000x1000"
    }
}
