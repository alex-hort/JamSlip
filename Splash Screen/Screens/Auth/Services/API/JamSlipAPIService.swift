//
//  JamSlipAPIService.swift
//  Splash Screen
//
//  Created by Alexis Horteales Espinosa on 24/01/26.
//

import Foundation
import FirebaseAuth
import Combine


// MARK: - JamSlip API Service
@MainActor
class JamSlipAPIService: ObservableObject {
    static let shared = JamSlipAPIService()
    
   
    private let baseURL = "https://jamslip-api-577659266872.us-central1.run.app"
    
    @Published var similarJams: [Jam] = []
    @Published var forYouJams: [Jam] = []
    @Published var hot100: [Jam] = []
    @Published var weeklyTop: [Jam] = []
    @Published var searchResults: [Jam] = []
    
    @Published var isLoadingSimilar = false
    @Published var isLoadingForYou = false
    @Published var isLoadingHot100 = false
    @Published var isLoadingWeekly = false
    @Published var isSearching = false
    
    private var currentUserId: String? { Auth.auth().currentUser?.uid }
    
    private init() {}
    
    // MARK: - 🔥 Similar Jams (Vector Search)
    func fetchSimilarJams(to jamId: String, limit: Int = 10) async -> [Jam] {
        isLoadingSimilar = true
        defer { isLoadingSimilar = false }
        
        guard let url = URL(string: "\(baseURL)/api/similar-jams") else { return [] }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        
        let body: [String: Any] = ["jamId": jamId, "limit": limit]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                print("❌ Similar Jams: HTTP error")
                return []
            }
            
            let apiResponse = try JSONDecoder().decode(SimilarJamsAPIResponse.self, from: data)
            let jams = apiResponse.jams.map { $0.toJam() }
            
            self.similarJams = jams
            print("✨ Similar Jams (\(apiResponse.method ?? "unknown")): \(jams.count)")
            
            return jams
        } catch {
            print("❌ Error fetchSimilarJams: \(error.localizedDescription)")
            return []
        }
    }
    
    // MARK: - ✨ For You (Personalized)
    func fetchForYou(limit: Int = 50) async -> [Jam] {
        guard let userId = currentUserId else {
            print("⚠️ No hay usuario logueado")
            return []
        }
        
        isLoadingForYou = true
        defer { isLoadingForYou = false }
        
        guard let url = URL(string: "\(baseURL)/api/for-you") else { return [] }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        
        let body: [String: Any] = ["userId": userId, "limit": limit]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                print("❌ For You: HTTP error")
                return []
            }
            
            let apiResponse = try JSONDecoder().decode(SimilarJamsAPIResponse.self, from: data)
            let jams = apiResponse.jams.map { $0.toJam() }
            
            self.forYouJams = jams
            print("✨ For You: \(jams.count) jams")
            
            return jams
        } catch {
            print("❌ Error fetchForYou: \(error.localizedDescription)")
            return []
        }
    }
    
    // MARK: - 🔥 Hot 100
    func fetchHot100() async -> [Jam] {
        isLoadingHot100 = true
        defer { isLoadingHot100 = false }
        
        guard let url = URL(string: "\(baseURL)/api/hot100") else { return [] }
        
        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 30
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                print("❌ Hot 100: HTTP error")
                return []
            }
            
            let apiResponse = try JSONDecoder().decode(JamsAPIResponse.self, from: data)
            let jams = apiResponse.jams.map { $0.toJam() }
            
            self.hot100 = jams
            print("🔥 Hot 100: \(jams.count) jams")
            
            return jams
        } catch {
            print("❌ Error fetchHot100: \(error.localizedDescription)")
            return []
        }
    }
    
    // MARK: - 📅 Weekly Top
    func fetchWeeklyTop() async -> [Jam] {
        isLoadingWeekly = true
        defer { isLoadingWeekly = false }
        
        guard let url = URL(string: "\(baseURL)/api/weekly-top") else { return [] }
        
        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 30
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                print("❌ Weekly Top: HTTP error")
                return []
            }
            
            let apiResponse = try JSONDecoder().decode(JamsAPIResponse.self, from: data)
            let jams = apiResponse.jams.map { $0.toJam() }
            
            self.weeklyTop = jams
            print("📅 Weekly Top: \(jams.count) jams")
            
            return jams
        } catch {
            print("❌ Error fetchWeeklyTop: \(error.localizedDescription)")
            return []
        }
    }
    
    // MARK: - 🎯 Update User Taste
    func updateUserTaste(jamId: String) async {
        guard let userId = currentUserId else { return }
        guard let url = URL(string: "\(baseURL)/api/update-taste") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15
        
        let body: [String: Any] = ["userId": userId, "jamId": jamId]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode == 200 {
                print("✅ User taste updated via backend")
            }
        } catch {
            print("❌ Error updateUserTaste: \(error.localizedDescription)")
        }
    }
    
    // MARK: - 🔍 Search
    func search(query: String, limit: Int = 20) async -> [Jam] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return [] }
        
        isSearching = true
        defer { isSearching = false }
        
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(baseURL)/api/search?q=\(encodedQuery)&limit=\(limit)") else {
            return []
        }
        
        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 30
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                print("❌ Search: HTTP error")
                return []
            }
            
            let apiResponse = try JSONDecoder().decode(JamsAPIResponse.self, from: data)
            let jams = apiResponse.jams.map { $0.toJam() }
            
            self.searchResults = jams
            print("🔍 Search '\(query)': \(jams.count) resultados")
            
            return jams
        } catch {
            print("❌ Error search: \(error.localizedDescription)")
            return []
        }
    }
    
    // MARK: - 🏥 Health Check
    func healthCheck() async -> Bool {
        guard let url = URL(string: "\(baseURL)/api/health") else { return false }
        
        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 10
            
            let (_, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                let isHealthy = httpResponse.statusCode == 200
                print(isHealthy ? "✅ Backend OK" : "❌ Backend error")
                return isHealthy
            }
            return false
        } catch {
            print("❌ Backend no disponible: \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - 🎵 Main Feed
    func fetchFeed(excludeIds: [String] = [], limit: Int = 50) async -> [Jam] {
        guard let userId = currentUserId else { return [] }
        guard let url = URL(string: "\(baseURL)/api/feed") else { return [] }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        
        let body: [String: Any] = [
            "userId": userId,
            "excludeIds": excludeIds,
            "limit": limit
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else { return [] }
            
            let apiResponse = try JSONDecoder().decode(FeedAPIResponse.self, from: data)
            let jams = apiResponse.jams.map { $0.toJam() }
            
            print("🎵 Feed (\(apiResponse.method ?? "?")): \(jams.count) jams")
            return jams
            
        } catch {
            print("❌ Error fetchFeed: \(error.localizedDescription)")
            return []
        }
    }
}
