//
//  SearchService.swift
//  Splash Screen
//
//  Created by Alexis Horteales Espinosa on 14/01/26.
//

import Foundation
import FirebaseFirestore
import Combine

/// Servicio para buscar usuarios y música
class SearchService: ObservableObject {
    static let shared = SearchService()
    
    private let db = Firestore.firestore()
    
    @Published var userResults: [User] = []
    @Published var trackResults: [AudiusTrack] = []
    @Published var isSearchingUsers = false
    @Published var isSearchingTracks = false
    
    private init() {}
    
    // MARK: - Search Users
    /// Busca usuarios por nombre o username
    func searchUsers(query: String) async {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        
        guard !trimmed.isEmpty else {
            await MainActor.run {
                self.userResults = []
            }
            return
        }
        
        await MainActor.run {
            self.isSearchingUsers = true
        }
        
        do {
            // Obtener usuarios y filtrar localmente
            // (Firestore no soporta búsqueda parcial de texto)
            let snapshot = try await db.collection("users")
                .limit(to: 100)
                .getDocuments()
            
            let queryLower = trimmed.lowercased()
            
            var matchedUsers: [User] = []
            
            for doc in snapshot.documents {
                if let user = try? doc.data(as: User.self) {
                    // Buscar en username y fullName (case insensitive)
                    let usernameMatch = user.username.lowercased().contains(queryLower)
                    let nameMatch = user.fullName.lowercased().contains(queryLower)
                    
                    if usernameMatch || nameMatch {
                        matchedUsers.append(user)
                    }
                }
            }
            
            await MainActor.run {
                self.userResults = matchedUsers
                self.isSearchingUsers = false
            }
            
        } catch {
            print("❌ Error searching users: \(error.localizedDescription)")
            await MainActor.run {
                self.userResults = []
                self.isSearchingUsers = false
            }
        }
    }
    
    // MARK: - Search Tracks
    /// Busca música en Audius
    func searchTracks(query: String) async {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        
        guard !trimmed.isEmpty else {
            await MainActor.run {
                self.trackResults = []
            }
            return
        }
        
        await MainActor.run {
            self.isSearchingTracks = true
        }
        
        do {
            let tracks = try await MusicService.shared.search(query: trimmed)
            
            await MainActor.run {
                self.trackResults = tracks
                self.isSearchingTracks = false
            }
            
        } catch {
            print("❌ Error searching tracks: \(error.localizedDescription)")
            await MainActor.run {
                self.trackResults = []
                self.isSearchingTracks = false
            }
        }
    }
    
    // MARK: - Search All
    /// Busca usuarios y música al mismo tiempo
    func searchAll(query: String) async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await self.searchUsers(query: query)
            }
            group.addTask {
                await self.searchTracks(query: query)
            }
        }
    }
    
    // MARK: - Clear Results
    func clearResults() {
        userResults = []
        trackResults = []
    }
}
