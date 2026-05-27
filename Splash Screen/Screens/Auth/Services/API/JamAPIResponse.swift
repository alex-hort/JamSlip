//
//  JamAPIResponse.swift
//  Splash Screen
//
//  Created by Alexis Horteales Espinosa on 24/01/26.
//
import Foundation

// MARK: - API Response Models
struct JamAPIResponse: Codable {
    let id: String
    let userId: String
    let username: String
    let userProfileImageUrl: String?
    let title: String
    let description: String
    let genre: String
    let moods: [String]
    let audioUrl: String
    let artworkUrl: String?
    let duration: Int
    let likesCount: Int?
    let repostsCount: Int?
    let savesCount: Int?
    let playsCount: Int?
    
    func toJam() -> Jam {
        return Jam(
            id: id,
            userId: userId,
            username: username,
            userProfileImageUrl: userProfileImageUrl,
            title: title,
            description: description,
            genre: genre,
            moods: moods,
            audioUrl: audioUrl,
            artworkUrl: artworkUrl,
            duration: duration,
            createdAt: Date(),
            likesCount: likesCount ?? 0,
            repostsCount: repostsCount ?? 0,
            savesCount: savesCount ?? 0,
            playsCount: playsCount ?? 0
        )
    }
}

struct SimilarJamsAPIResponse: Codable {
    let jams: [JamAPIResponse]
    let method: String?
}

struct FeedStats: Codable {
    let personalized: Int?
    let discovery: Int?
}

struct FeedAPIResponse: Codable {
    let jams: [JamAPIResponse]
    let method: String?
    let message: String?
    let stats: FeedStats?
}

struct JamsAPIResponse: Codable {
    let jams: [JamAPIResponse]
    let message: String?
    let method: String?
    let stats: FeedStats?
}
