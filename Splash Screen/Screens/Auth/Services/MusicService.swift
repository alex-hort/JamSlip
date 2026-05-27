//
//  MusicService.swift
//  Splash Screen
//
//  Created by Alexis Horteales Espinosa on 14/01/26.
//

import Foundation
import AVFoundation

class MusicService {
    static let shared = MusicService()
    
    private let audiusBaseURL = "https://api.audius.co/v1"
    private let appName = "JamSlip"
    
    private let session: URLSession
    
    // Tracks ya mostrados - persistido
    private var shownTrackIds: Set<String> = []
    private let shownTracksKey = "ShownTrackIds_v2"
    private let maxShownCache = 500
    
    private let genres = ["Electronic", "Hip-Hop", "Pop", "Rock", "R&B", "Latin", "House", "Indie", "Trap", "Lo-Fi", "Ambient", "Jazz", "Soul", "Funk", "Reggaeton"]
    private let timeRanges = ["week", "month", "allTime"]
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        self.session = URLSession(configuration: config)
        
        loadShownTracks()
    }
    
    // MARK: - Shown Tracks Management
    
    private func loadShownTracks() {
        if let savedIds = UserDefaults.standard.array(forKey: shownTracksKey) as? [String] {
            shownTrackIds = Set(savedIds)
        }
    }
    
    private func saveShownTracks() {
        if shownTrackIds.count > maxShownCache {
            shownTrackIds = Set(Array(shownTrackIds).suffix(300))
        }
        UserDefaults.standard.set(Array(shownTrackIds), forKey: shownTracksKey)
    }
    
    /// Filtra tracks ya mostrados y marca los nuevos como vistos
    private func filterAndMarkShown(_ tracks: [AudiusTrack]) -> [AudiusTrack] {
        let newTracks = tracks.filter { !shownTrackIds.contains($0.id) }
        newTracks.forEach { shownTrackIds.insert($0.id) }
        saveShownTracks()
        return newTracks
    }
    
    /// Verifica si un track ya fue mostrado
    func isTrackShown(_ trackId: String) -> Bool {
        shownTrackIds.contains(trackId)
    }
    
    /// Marca un track como visto (llamar cuando el usuario lo ve)
    func markTrackAsShown(_ trackId: String) {
        shownTrackIds.insert(trackId)
        saveShownTracks()
    }
    
    func resetCache() {
        // No limpia shownTrackIds - eso es intencional
    }
    
    func clearAllHistory() {
        shownTrackIds.removeAll()
        UserDefaults.standard.removeObject(forKey: shownTracksKey)
    }
    
    // MARK: - Get Tracks
    
    func getPersonalizedTracks(limit: Int = 30) async throws -> [AudiusTrack] {
        var allTracks: [AudiusTrack] = []
        
        // 1. Trending
        let time = timeRanges.randomElement() ?? "week"
        let trendingTracks = try await getTrendingTracks(limit: 50, time: time)
        allTracks.append(contentsOf: trendingTracks)
        
        // 2. Underground
        do {
            let undergroundTracks = try await getUndergroundTracks(limit: 40)
            allTracks.append(contentsOf: undergroundTracks)
        } catch {}
        
        // 3. Genre random
        let genre = genres.randomElement() ?? "Electronic"
        do {
            let genreTracks = try await searchByGenre(genre: genre, limit: 40)
            allTracks.append(contentsOf: genreTracks)
        } catch {}
        
        // Remover duplicados por ID
        var uniqueIds = Set<String>()
        let uniqueTracks = allTracks.filter { track in
            if uniqueIds.contains(track.id) { return false }
            uniqueIds.insert(track.id)
            return true
        }
        
        // Filtrar ya mostrados
        var filtered = filterAndMarkShown(uniqueTracks)
        
        // Si no hay suficientes, buscar más variedad
        if filtered.count < limit {
            do {
                let moreTracks = try await getMoreVariety(limit: 50)
                let moreFiltered = filterAndMarkShown(moreTracks)
                filtered.append(contentsOf: moreFiltered)
            } catch {}
        }
        
        // Si aún no hay suficientes, incluir algunos ya vistos (mejor que nada)
        if filtered.count < 5 {
            let fallback = uniqueTracks.shuffled().prefix(limit)
            return Array(fallback)
        }
        
        filtered.shuffle()
        
        // Precargar imágenes
        Task.detached(priority: .background) {
            await self.preloadAlbumArt(for: Array(filtered.prefix(15)))
        }
        
        return Array(filtered.prefix(limit))
    }
    
    func getTrendingTracks(limit: Int = 30, time: String = "week") async throws -> [AudiusTrack] {
        let urlString = "\(audiusBaseURL)/tracks/trending?app_name=\(appName)&limit=\(limit)&time=\(time)"
        
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        
        let (data, _) = try await session.data(from: url)
        let response = try JSONDecoder().decode(AudiusTracksResponse.self, from: data)
        
        return response.data
    }
    
    func getUndergroundTracks(limit: Int = 20) async throws -> [AudiusTrack] {
        let urlString = "\(audiusBaseURL)/tracks/trending/underground?app_name=\(appName)&limit=\(limit)"
        
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        
        let (data, _) = try await session.data(from: url)
        let response = try JSONDecoder().decode(AudiusTracksResponse.self, from: data)
        
        return response.data
    }
    
    func searchByGenre(genre: String, limit: Int = 20) async throws -> [AudiusTrack] {
        let encoded = genre.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? genre
        let urlString = "\(audiusBaseURL)/tracks/trending?app_name=\(appName)&genre=\(encoded)&limit=\(limit)"
        
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        
        let (data, _) = try await session.data(from: url)
        let response = try JSONDecoder().decode(AudiusTracksResponse.self, from: data)
        
        return response.data
    }
    
    func getMoreVariety(limit: Int = 30) async throws -> [AudiusTrack] {
        let searchTerms = ["chill", "vibe", "beat", "summer", "night", "love", "dream", "wave", "fire", "mood", "relax", "party", "good", "feel", "groove", "bass", "remix", "dance"]
        let term = searchTerms.randomElement() ?? "vibe"
        return try await search(query: term)
    }
    
    func search(query: String) async throws -> [AudiusTrack] {
        guard !query.isEmpty else {
            return try await getTrendingTracks()
        }
        
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let urlString = "\(audiusBaseURL)/tracks/search?query=\(encoded)&app_name=\(appName)&limit=30"
        
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        
        let (data, _) = try await session.data(from: url)
        let response = try JSONDecoder().decode(AudiusTracksResponse.self, from: data)
        return response.data
    }
    
    // MARK: - Recommendations
    
    func getRecommendations(for track: AudiusTrack) async throws -> [AudiusTrack] {
        var results: [AudiusTrack] = []
        
        // Buscar por artista
        let artistResults = try await search(query: track.user.name)
        results.append(contentsOf: artistResults)
        
        // Buscar por título parcial
        let titleWords = track.title.split(separator: " ").prefix(2).joined(separator: " ")
        if !titleWords.isEmpty {
            let titleResults = try await search(query: titleWords)
            results.append(contentsOf: titleResults)
        }
        
        // Remover duplicados y el track actual
        var uniqueIds = Set<String>()
        uniqueIds.insert(track.id) // Excluir el track actual
        
        let uniqueResults = results.filter { t in
            if uniqueIds.contains(t.id) { return false }
            uniqueIds.insert(t.id)
            return true
        }
        
        // Filtrar ya mostrados
        let filtered = filterAndMarkShown(uniqueResults)
        
        // Precargar imágenes
        Task.detached(priority: .background) {
            await self.preloadAlbumArt(for: Array(filtered.prefix(10)))
        }
        
        return Array(filtered.shuffled().prefix(10))
    }
    
    // MARK: - Preload
    
    func preloadAlbumArt(for tracks: [AudiusTrack]) async {
        await withTaskGroup(of: Void.self) { group in
            for track in tracks {
                if let imageURL = track.imageURL {
                    group.addTask {
                        await ImageCacheService.shared.preloadImage(from: imageURL)
                    }
                }
                // También precargar foto del artista
                if let profileURL = track.user.profilePicture, !profileURL.isEmpty {
                    group.addTask {
                        await ImageCacheService.shared.preloadImage(from: profileURL)
                    }
                }
            }
        }
    }
}

// MARK: - Hashable
extension AudiusTrack: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
