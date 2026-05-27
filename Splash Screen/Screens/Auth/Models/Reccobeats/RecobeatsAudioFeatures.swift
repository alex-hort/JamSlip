//
//  RecobeatsAudioFeatures.swift
//  Splash Screen
//
//  Created by Alexis Horteales Espinosa on 14/01/26.
//

import Foundation

// MARK: - Recobeats Models
struct RecobeatsAudioFeatures: Codable {
    let acousticness: Double
    let danceability: Double
    let energy: Double
    let instrumentalness: Double
    let liveness: Double
    let loudness: Double
    let speechiness: Double
    let tempo: Double
    let valence: Double
    
    func toTags() -> [String] {
        var tags: [String] = []
        
        if energy > 0.7 { tags.append("energetic") }
        if valence > 0.6 { tags.append("happy") }
        if danceability > 0.65 { tags.append("dance") }
        if acousticness > 0.8 { tags.append("acoustic") }
        if tempo > 130 { tags.append("fast") }
        
        if tags.isEmpty {
            tags.append("pop")
        }
        
        return Array(tags.prefix(3))
    }
}
