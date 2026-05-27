//
//  Jam.swift
//  Splash Screen
//
//  Created by Alexis Horteales Espinosa on 22/01/26.
//
import Foundation
import FirebaseFirestore

struct Jam: Identifiable, Codable, Equatable {
    @DocumentID var documentId: String?
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
    
    let createdAt: Date
    
    var likesCount: Int
    var repostsCount: Int
    var savesCount: Int
    var playsCount: Int
    
    // ✅ NUEVO: Spatial Audio (solo usuarios premium)
    var hasSpatialAudio: Bool?
    
    // Vector Search fields
    var embedding: [Double]?
    var embeddingText: String?
    var embeddingStatus: String?
    
    init(
        id: String = UUID().uuidString,
        userId: String,
        username: String,
        userProfileImageUrl: String? = nil,
        title: String,
        description: String,
        genre: String,
        moods: [String],
        audioUrl: String,
        artworkUrl: String? = nil,
        duration: Int,
        createdAt: Date = Date(),
        likesCount: Int = 0,
        repostsCount: Int = 0,
        savesCount: Int = 0,
        playsCount: Int = 0,
        hasSpatialAudio: Bool? = nil, // ✅ NUEVO
        embedding: [Double]? = nil,
        embeddingText: String? = nil,
        embeddingStatus: String? = nil
    ) {
        self.id = id
        self.userId = userId
        self.username = username
        self.userProfileImageUrl = userProfileImageUrl
        self.title = title
        self.description = description
        self.genre = genre
        self.moods = moods
        self.audioUrl = audioUrl
        self.artworkUrl = artworkUrl
        self.duration = duration
        self.createdAt = createdAt
        self.likesCount = likesCount
        self.repostsCount = repostsCount
        self.savesCount = savesCount
        self.playsCount = playsCount
        self.hasSpatialAudio = hasSpatialAudio
        self.embedding = embedding
        self.embeddingText = embeddingText
        self.embeddingStatus = embeddingStatus
    }
    
    // Duración formateada
    var formattedDuration: String {
        let minutes = duration / 60
        let seconds = duration % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    // Fecha formateada
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM dd"
        return formatter.string(from: createdAt).uppercased()
    }
    
    // Moods formateados
    var formattedMoods: String {
        moods.map { $0.capitalized }.joined(separator: " • ")
    }
    
    // Generar texto para embedding (usado por la extensión de Firebase)
    var textForEmbedding: String {
        let moodsText = moods.joined(separator: " ")
        return "\(genre) \(moodsText) \(title) \(description)".lowercased()
    }
    
    // Score de popularidad
    var popularityScore: Double {
        let likeWeight = 3.0
        let saveWeight = 2.0
        let repostWeight = 4.0
        let playWeight = 0.5
        
        return Double(likesCount) * likeWeight +
               Double(savesCount) * saveWeight +
               Double(repostsCount) * repostWeight +
               Double(playsCount) * playWeight
    }
}



