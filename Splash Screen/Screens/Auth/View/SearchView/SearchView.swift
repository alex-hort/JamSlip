//
//  SearchView.swift
//  Splash Screen
//
//  Created by Alexis Horteales Espinosa on 14/01/26.
//
import SwiftUI
import FirebaseAuth

struct SearchView: View {
    
    @State private var searchText = ""
    @StateObject private var searchService = SearchService.shared
    @StateObject private var audioPlayer = AudioPlayerManager.shared
    
    // Para navegación al perfil de usuario
    @State private var selectedUser: User?
    @State private var showUserProfile = false
    
    // ✅ Búsquedas recientes
    @State private var recentSearches: [RecentSearch] = []
    
    private var searchesKey: String {
        guard let uid = Auth.auth().currentUser?.uid else { return "recent_searches_guest" }
        return "recent_searches_\(uid)"
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Barra de búsqueda con cancel
                searchBar
                
                // Contenido
                if searchText.isEmpty {
                    // Mostrar búsquedas recientes
                    recentSearchesView
                } else {
                    // Mostrar resultados de búsqueda
                    searchResultsView
                }
            }
            .background(Color.black)
            .navigationBarHidden(true)
            .onChange(of: searchText) { _, newValue in
                // Debounce search
                Task {
                    try? await Task.sleep(nanoseconds: 300_000_000) // 0.3s
                    if !newValue.isEmpty {
                        await searchService.searchUsers(query: newValue)
                    }
                }
            }
            .navigationDestination(isPresented: $showUserProfile) {
                if let user = selectedUser {
                    UserProfileView(user: user)
                }
            }
            .onAppear {
                loadRecentSearches()
            }
        }
    }
    
    // MARK: - Search Bar
    private var searchBar: some View {
        HStack(spacing: 12) {
            // Barra de búsqueda
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                
                TextField("", text: $searchText, prompt: Text("Search").foregroundColor(.gray))
                    .foregroundColor(.white)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(10)
            .background(Color.white.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            
            // Botón Cancel (solo cuando hay texto)
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                } label: {
                    Text("Cancel")
                        .foregroundColor(.white)
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .animation(.easeInOut(duration: 0.2), value: searchText.isEmpty)
    }
    
    // MARK: - Recent Searches
    private var recentSearchesView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if !recentSearches.isEmpty {
                    // Header
                    Text("Recent")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Lista de búsquedas recientes
                    ForEach(recentSearches) { search in
                        RecentSearchRow(
                            search: search,
                            onTap: {
                                handleRecentSearchTap(search)
                            },
                            onDelete: {
                                deleteRecentSearch(search)
                            }
                        )
                        
                        Divider()
                            .background(Color.white.opacity(0.1))
                            .padding(.leading, 70)
                    }
                } else {
                    // Estado vacío
                    VStack(spacing: 16) {
                        Spacer()
                        
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 60))
                            .foregroundColor(.white.opacity(0.2))
                        
                        Text("Search for people")
                            .font(.headline)
                            .foregroundColor(.white.opacity(0.5))
                        
                        Text("Find people to follow")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.3))
                        
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }
    
    // MARK: - Search Results
    private var searchResultsView: some View {
        Group {
            if searchService.isSearchingUsers {
                LoadingSearchView()
            } else if searchService.userResults.isEmpty {
                NoResultsView(message: "No users found")
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(searchService.userResults, id: \.uid) { user in
                            UserSearchRow(user: user)
                                .onTapGesture {
                                    handleUserTap(user)
                                }
                            
                            Divider()
                                .background(Color.white.opacity(0.1))
                                .padding(.leading, 70)
                        }
                    }
                }
            }
        }
    }
    
    
    // MARK: - Handle Taps
    private func handleUserTap(_ user: User) {
        // Guardar en recientes
        saveRecentSearch(user)
        
        // Navegar al perfil
        selectedUser = user
        showUserProfile = true
    }
    
    private func handleRecentSearchTap(_ search: RecentSearch) {
        selectedUser = search.user
        showUserProfile = true
    }
    
    // MARK: - Recent Searches Management
   
    private func loadRecentSearches() {
        if let data = UserDefaults.standard.data(forKey: searchesKey),
           let searches = try? JSONDecoder().decode([RecentSearch].self, from: data) {
            recentSearches = searches
        }
    }
    
  
    private func saveRecentSearch(_ user: User) {
        recentSearches.removeAll { $0.user.uid == user.uid }
        
        let search = RecentSearch(user: user, searchedAt: Date())
        recentSearches.insert(search, at: 0)
        
        if recentSearches.count > 20 {
            recentSearches = Array(recentSearches.prefix(20))
        }
        
        if let data = try? JSONEncoder().encode(recentSearches) {
            UserDefaults.standard.set(data, forKey: searchesKey) // ✅
        }
    }
    
    private func deleteRecentSearch(_ search: RecentSearch) {
        recentSearches.removeAll { $0.id == search.id }
        
        if let data = try? JSONEncoder().encode(recentSearches) {
            UserDefaults.standard.set(data, forKey: searchesKey) // ✅
        }
    }
    
    private func clearRecentSearches() {
        recentSearches = []
        UserDefaults.standard.removeObject(forKey: searchesKey) // ✅
    }
}

// MARK: - Recent Search Model
struct RecentSearch: Identifiable, Codable {
    let id: String
    let user: User
    let searchedAt: Date
    
    init(user: User, searchedAt: Date) {
        self.id = UUID().uuidString
        self.user = user
        self.searchedAt = searchedAt
    }
}

// MARK: - Recent Search Row
struct RecentSearchRow: View {
    let search: RecentSearch
    let onTap: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Foto de perfil
            profileImage
            
            // Info del usuario
            VStack(alignment: .leading, spacing: 4) {
                Text(search.user.fullName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                HStack(spacing: 4) {
                    Text("@\(search.user.username)")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                        .lineLimit(1)
                    
                    // ✅ Badge de verificación (usando propiedad computada)
                    if search.user.isPremium {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [
                                        Color(hex: "7DA6FF"),
                                        Color(hex: "4B70F5")
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    }
                }
            }
            
            Spacer()
            
            // Botón X para eliminar
            Button {
                onDelete()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
                    .frame(width: 32, height: 32)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }
    
    private var profileImage: some View {
        Group {
            if let profileUrl = search.user.profileImageUrl, !profileUrl.isEmpty {
                AsyncImage(url: URL(string: profileUrl)) { phase in
                    switch phase {
                    case .empty:
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .overlay {
                                ProgressView()
                                    .tint(.white)
                                    .scaleEffect(0.6)
                            }
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure:
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .overlay {
                                Image(systemName: "person.fill")
                                    .foregroundColor(.white.opacity(0.5))
                            }
                    @unknown default:
                        EmptyView()
                    }
                }
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .overlay {
                        Image(systemName: "person.fill")
                            .foregroundColor(.white.opacity(0.5))
                    }
            }
        }
        .frame(width: 50, height: 50)
        .clipShape(Circle())
    }
}

// MARK: - User Search Row
struct UserSearchRow: View {
    let user: User
    
    var body: some View {
        HStack(spacing: 12) {
            // Foto de perfil
            profileImage
            
            // Info del usuario
            VStack(alignment: .leading, spacing: 4) {
                Text(user.fullName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                HStack(spacing: 4) {
                    Text("@\(user.username)")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                        .lineLimit(1)
                    
                    // ✅ Badge de verificación (usando propiedad computada)
                    if user.isPremium {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [
                                        Color(hex: "7DA6FF"),
                                        Color(hex: "4B70F5")
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    }
                }
            }
            
            Spacer()
            
            // Flecha
            Image(systemName: "chevron.right")
                .font(.system(size: 14))
                .foregroundColor(.gray)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
    
    private var profileImage: some View {
        Group {
            if let profileUrl = user.profileImageUrl, !profileUrl.isEmpty {
                AsyncImage(url: URL(string: profileUrl)) { phase in
                    switch phase {
                    case .empty:
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .overlay {
                                ProgressView()
                                    .tint(.white)
                                    .scaleEffect(0.6)
                            }
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure:
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .overlay {
                                Image(systemName: "person.fill")
                                    .foregroundColor(.white.opacity(0.5))
                            }
                    @unknown default:
                        EmptyView()
                    }
                }
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .overlay {
                        Image(systemName: "person.fill")
                            .foregroundColor(.white.opacity(0.5))
                    }
            }
        }
        .frame(width: 50, height: 50)
        .clipShape(Circle())
    }
}

// MARK: - Loading View
struct LoadingSearchView: View {
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            
            ProgressView()
                .tint(.white)
                .scaleEffect(1.2)
            
            Text("Searching...")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.6))
            
            Spacer()
        }
    }
}

// MARK: - No Results View
struct NoResultsView: View {
    let message: String
    
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "magnifyingglass")
                .font(.system(size: 50))
                .foregroundColor(.white.opacity(0.2))
            
            Text(message)
                .font(.headline)
                .foregroundColor(.white.opacity(0.5))
            
            Spacer()
        }
    }
}


