//
//  JamFeedCardView.swift
//  Splash Screen
//
//  Created by Alexis Horteales Espinosa on 22/01/26.
import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct JamFeedCardView: View {
    let jam: Jam
    var repostInfo: JamRepost? = nil
    
    @ObservedObject private var audioPlayer = AudioPlayerManager.shared
    @StateObject private var followService = FollowService.shared
    @StateObject private var repostService = JamRepostService.shared
    @EnvironmentObject var authVM: AuthViewModel
    
    @State private var isLiked = false
    @State private var isSaved = false
    @State private var isReposted = false
    @State private var likesCount: Int
    @State private var savesCount: Int
    @State private var repostsCount: Int
    @State private var showUserProfile = false
    @State private var followButtonScale: CGFloat = 1.0
    @State private var userToShow: User?
    @State private var isUserPremium = false
    @State private var isLoadingProfile = false // ✅ Estado de carga
    
    init(jam: Jam, repostInfo: JamRepost? = nil) {
        self.jam = jam
        self.repostInfo = repostInfo
        _likesCount = State(initialValue: jam.likesCount)
        _savesCount = State(initialValue: jam.savesCount)
        _repostsCount = State(initialValue: jam.repostsCount)
    }
    
    private var isCurrentlyPlaying: Bool {
        audioPlayer.currentJam?.id == jam.id && audioPlayer.isPlaying
    }
    
    private var isOwnJam: Bool {
        Auth.auth().currentUser?.uid == jam.userId
    }
    
    private var isFollowingUser: Bool {
        followService.isFollowing(jam.userId)
    }
    
    var body: some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(Color.black)
            )
            .clipShape(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
            )
            .shadow(color: .black.opacity(0.6), radius: 25, y: 14)
            .task {
                await checkStatus()
                await followService.fetchFollowingList()
                await repostService.fetchRepostCount(for: jam.id)
                repostsCount = repostService.getRepostCount(for: jam.id)
                await checkUserPremiumStatus()
                
                MyJamsService.shared.incrementPlayCount(for: jam.id)
            }
            .fullScreenCover(isPresented: $showUserProfile) {
                if let user = userToShow {
                    NavigationStack { UserProfileView(user: user) }
                }
            }
            .onReceive(repostService.repostCountsDidChange) { _ in
                if let count = repostService.repostCounts[jam.id] {
                    repostsCount = count
                }
            }
            .onChange(of: repostService.repostCounts) { _, newCounts in
                if let count = newCounts[jam.id] {
                    repostsCount = count
                }
            }
    }
    
    // MARK: - Main Content
    private var content: some View {
        GeometryReader { geometry in
            ZStack {
                artworkView(size: geometry.size)
                sideButtons
                    .frame(
                        maxWidth: .infinity,
                        maxHeight: .infinity,
                        alignment: .bottomTrailing
                    )
            }
        }
    }

    private func artworkView(size: CGSize) -> some View {
        ZStack {
            Button {
                audioPlayer.togglePlayPause(for: jam)
            } label: {
                Group {
                    if let artworkUrl = jam.artworkUrl,
                       let url = URL(string: artworkUrl) {
                        CachedAsyncImage(url: url) { image in
                            image
                                .resizable()
                                .scaledToFill()
                        } placeholder: {
                            defaultArtwork
                        }
                    } else {
                        defaultArtwork
                    }
                }
                .frame(width: size.width, height: size.height)
                .clipped()
            }
            .buttonStyle(.plain)

            artworkInfoOverlay
        }
    }
    
    private var artworkInfoOverlay: some View {
        VStack {
            Spacer()
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(jam.title)
                        .font(.system(size: 18, weight: .bold))
                        .lineLimit(1)
                    
                    HStack(spacing: 6) {
                        Text(jam.formattedDate)
                            .font(.system(size: 12, weight: .medium))
                            .opacity(0.7)
                        
                        Text("•")
                            .font(.system(size: 10))
                            .opacity(0.5)
                        
                        HStack(spacing: 3) {
                            Text("@\(jam.username)")
                                .font(.system(size: 13))
                                .opacity(0.85)
                            
                            if isUserPremium {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 11))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [Color(hex: "7DA6FF"), Color(hex: "4B70F5")],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .shadow(color: .black.opacity(0.3), radius: 1, y: 0.5)
                            }
                        }
                    }
                }
                
                Spacer()
                
                Text(jam.genre.uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
            }
            .foregroundColor(.white)
            .padding(14)
            .padding(.bottom, 10)
            .background(
                LinearGradient(
                    colors: [.clear, .black.opacity(0.7)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
    }
    
    private var sideButtons: some View {
        VStack(spacing: 28) {
            profileButton

            SideIconButton(
                icon: isLiked ? "heart.fill" : "heart",
                count: likesCount,
                color: isLiked ? .red : .white
            ) { toggleLike() }

            SideIconButton(
                icon: "arrow.2.squarepath",
                count: repostsCount,
                color: isReposted ? .green : .white
            ) {
                toggleRepost()
            }

            SideIconButton(
                icon: isSaved ? "bookmark.fill" : "bookmark",
                count: savesCount,
                color: isSaved ? .yellow : .white
            ) { toggleSave() }
        }
        .padding(.trailing, 6)
        .padding(.bottom, 80)
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity,
            alignment: .bottomTrailing
        )
    }
    
    // MARK: - Profile
    private var profileButton: some View {
        ZStack(alignment: .bottomTrailing) {
            Button {
                if !isOwnJam {
                    // ✅ Cargar datos ANTES de mostrar
                    loadFullUserDataAndShowProfile()
                }
            } label: {
                ZStack {
                    profileImage
                    
                    // ✅ Indicador de carga
                    if isLoadingProfile {
                        Circle()
                            .fill(Color.black.opacity(0.6))
                            .frame(width: 54, height: 54)
                        
                        ProgressView()
                            .scaleEffect(0.8)
                            .tint(.white)
                    }
                }
            }
            .disabled(isLoadingProfile) // ✅ Deshabilitar mientras carga
            
            if !isOwnJam && !isFollowingUser && !isLoadingProfile {
                Button { followUser() } label: {
                    Circle()
                        .fill(Color.purple)
                        .frame(width: 22, height: 22)
                        .overlay(
                            Image(systemName: "plus")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                        )
                        .scaleEffect(followButtonScale)
                        .shadow(radius: 4)
                }
                .offset(y: 6)
            }
        }
        .animation(.spring(response: 0.3), value: isFollowingUser)
    }
    
    private var profileImage: some View {
        Group {
            if let urlString = jam.userProfileImageUrl,
               let url = URL(string: urlString) {
                CachedAsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: { profilePlaceholder }
            } else {
                profilePlaceholder
            }
        }
        .frame(width: 54, height: 54)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.white.opacity(0.8), lineWidth: 2))
        .shadow(radius: 6)
    }
    
    private var profilePlaceholder: some View {
        Circle()
            .fill(Color.gray.opacity(0.35))
            .overlay(
                Image(systemName: "person.fill")
                    .foregroundColor(.white.opacity(0.6))
            )
    }
    
    private var defaultArtwork: some View {
        LinearGradient(
            colors: [.purple.opacity(0.7), .blue.opacity(0.5)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(
            Image(systemName: "music.note")
                .font(.system(size: 90))
                .foregroundColor(.white.opacity(0.25))
        )
    }
    
    // MARK: - ✅ Verificar estado premium del usuario
    private func checkUserPremiumStatus() async {
        let db = Firestore.firestore()
        
        do {
            let doc = try await db.collection("users").document(jam.userId).getDocument()
            
            if let data = doc.data(),
               let isPremium = data["isPremium"] as? Bool,
               isPremium {
                
                if let expiresAt = data["premiumExpiresAt"] as? Timestamp {
                    let isValid = expiresAt.dateValue() > Date()
                    await MainActor.run {
                        self.isUserPremium = isValid
                    }
                } else {
                    await MainActor.run {
                        self.isUserPremium = false
                    }
                }
            } else {
                await MainActor.run {
                    self.isUserPremium = false
                }
            }
        } catch {
            await MainActor.run {
                self.isUserPremium = false
            }
        }
    }
    
    // MARK: - Actions
    private func toggleLike() {
        let prev = isLiked
        let count = likesCount
        isLiked.toggle()
        likesCount += isLiked ? 1 : -1
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        
        Task {
            do {
                try await MyJamsService.shared.toggleLike(jam)
                
                if !prev {
                    if let currentUser = authVM.currentUser, jam.userId != currentUser.uid {
                        await NotificationService.shared.sendJamLikeNotification(
                            toUserId: jam.userId,
                            fromUser: currentUser,
                            jam: jam
                        )
                    }
                    
                    if let repost = repostInfo,
                       let currentUser = authVM.currentUser,
                       repost.userId != currentUser.uid {
                        await NotificationService.shared.sendLikeNotification(
                            toUserId: repost.userId,
                            fromUser: currentUser,
                            track: AudiusTrack(
                                id: jam.id,
                                title: jam.title,
                                duration: jam.duration,
                                artwork: jam.artworkUrl != nil ? Artwork(small: jam.artworkUrl!, medium: jam.artworkUrl!, large: jam.artworkUrl!) : nil,
                                coverPhoto: nil,
                                user: AudiusUser(name: jam.username, handle: jam.username),
                                playCount: nil,
                                favoriteCount: nil
                            )
                        )
                    }
                }
            } catch {
                await MainActor.run {
                    isLiked = prev
                    likesCount = count
                }
            }
        }
    }
    
    private func toggleSave() {
        let prev = isSaved
        let count = savesCount
        isSaved.toggle()
        savesCount += isSaved ? 1 : -1
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        
        Task {
            do { try await MyJamsService.shared.toggleSave(jam) }
            catch {
                await MainActor.run {
                    isSaved = prev
                    savesCount = count
                }
            }
        }
    }
    
    private func toggleRepost() {
        let prev = isReposted
        let count = repostsCount
        
        repostService.optimisticToggleRepost(jamId: jam.id)
        isReposted.toggle()
        repostsCount += isReposted ? 1 : -1
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        
        Task {
            do {
                guard let user = authVM.currentUser else { return }
                try await repostService.syncRepostToFirebase(
                    jam: jam,
                    fromUser: user,
                    wasReposted: prev,
                    comment: nil
                )
            } catch {
                await MainActor.run {
                    isReposted = prev
                    repostsCount = count
                    repostService.optimisticToggleRepost(jamId: jam.id)
                }
            }
        }
    }
    
    private func followUser() {
        withAnimation(.spring(response: 0.2)) {
            followButtonScale = 1.4
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.spring(response: 0.3)) {
                followButtonScale = 0.1
            }
        }
        
        Task {
            try? await followService.follow(targetUserId: jam.userId)
        }
    }
    
    private func checkStatus() async {
        isLiked = await MyJamsService.shared.isJamLiked(jam.id)
        isSaved = await MyJamsService.shared.isJamSaved(jam.id)
        isReposted = repostService.isReposted(jam.id)
        
        if repostService.myRepostedJamIds.isEmpty {
            await repostService.fetchMyReposts()
            isReposted = repostService.isReposted(jam.id)
        }
    }
    
    // ✅ NUEVA FUNCIÓN: Cargar datos completos ANTES de mostrar perfil
    private func loadFullUserDataAndShowProfile() {
        guard !isLoadingProfile else { return }
        
        isLoadingProfile = true
        
        Task {
            let db = Firestore.firestore()
            
            do {
                let doc = try await db.collection("users").document(jam.userId).getDocument()
                
                guard let data = doc.data() else {
                    await MainActor.run {
                        isLoadingProfile = false
                    }
                    return
                }
                
                var premiumExpiresAt: Date? = nil
                if let timestamp = data["premiumExpiresAt"] as? Timestamp {
                    premiumExpiresAt = timestamp.dateValue()
                }
                
                var joinedDate: Date? = nil
                if let timestamp = data["joinedDate"] as? Timestamp {
                    joinedDate = timestamp.dateValue()
                }
                
                let fullUser = User(
                    uid: jam.userId,
                    email: data["email"] as? String ?? "",
                    fullName: data["fullName"] as? String ?? jam.username,
                    username: data["username"] as? String ?? jam.username,
                    bio: data["bio"] as? String,
                    profileImageUrl: data["profileImageUrl"] as? String,
                    bannerImageUrl: data["bannerImageUrl"] as? String,
                    joinedDate: joinedDate,
                    followingCount: data["followingCount"] as? Int ?? 0,
                    followersCount: data["followersCount"] as? Int ?? 0,
                    jamsCount: data["jamsCount"] as? Int ?? 0,
                    isPremium: data["isPremium"] as? Bool,
                    premiumExpiresAt: premiumExpiresAt,
                    isInTrialPeriod: data["isInTrialPeriod"] as? Bool
                )
                
                await MainActor.run {
                    userToShow = fullUser
                    isLoadingProfile = false
                    showUserProfile = true
                    
                    print("✅ Usuario cargado para perfil:")
                    print("   Nombre: \(fullUser.fullName)")
                    print("   ProfileImage: \(fullUser.profileImageUrl ?? "nil")")
                    print("   Premium: \(fullUser.isPremium)")
                }
            } catch {
                print("❌ Error cargando datos del usuario: \(error)")
                await MainActor.run {
                    isLoadingProfile = false
                }
            }
        }
    }
}









