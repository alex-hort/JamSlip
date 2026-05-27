//
//  NotificationsView.swift
//  Splash Screen
//
//  Created by Alexis Horteales Espinosa on 19/01/26.
//
import SwiftUI
import FirebaseFirestore

struct NotificationsView: View {
    
    @StateObject private var notificationService = NotificationService.shared
    @StateObject private var followService = FollowService.shared
    
    // Navigation states
    @State private var selectedNotification: JamNotification?
    @State private var showJamView = false
    @State private var showUserProfile = false
    @State private var userToShow: User?
    @State private var isLoadingUser = false
    
    private let db = Firestore.firestore()
    
    var body: some View {
        NavigationStack {
            ZStack {
                VStack(spacing: 0) {
                    header
                    
                    if notificationService.isLoading {
                        loadingView
                    } else if notificationService.notifications.isEmpty {
                        emptyView
                    } else {
                        notificationsList
                    }
                }
                .background(Color.black)
                
                // Loading overlay when fetching user
                if isLoadingUser {
                    Color.black.opacity(0.5)
                        .ignoresSafeArea()
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(1.5)
                }
            }
            .navigationBarHidden(true)
            .fullScreenCover(isPresented: $showJamView) {
                if let notification = selectedNotification {
                    NotiJamsView(notification: notification)
                }
            }
            .fullScreenCover(isPresented: $showUserProfile) {
                if let user = userToShow {
                    NavigationStack {
                        UserProfileView(user: user)
                    }
                }
            }
        }
        .task {
            await notificationService.fetchNotifications()
            notificationService.startListening()
            // ✅ CRÍTICO: Iniciar listener de unreadCount
            notificationService.startListeningToUnreadCount()
            await followService.fetchFollowingList()
        }
        // ✅ Marcar como leídas cuando SALE de la vista
        .onDisappear {
            Task {
                await notificationService.markAllAsRead()
            }
        }
    }
    
    // MARK: - Header
    private var header: some View {
        HStack {
            Text("Notifications")
                .foregroundColor(.white)
                .font(.system(size: 20, weight: .bold))
            
            Spacer()
            
            // ✅ Badge actualizado en tiempo real
            if notificationService.unreadCount > 0 {
                Text("\(notificationService.unreadCount)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        LinearGradient(
                            colors: [Color.purple, Color.pink],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(Capsule())
                    .shadow(color: .purple.opacity(0.5), radius: 4, y: 2)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .padding(.bottom, 6)
        .background(Color.black)
    }

    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView()
                .tint(.white)
                .scaleEffect(1.2)
            Text("Loading...")
                .foregroundColor(.gray)
                .font(.subheadline)
                .padding(.top, 12)
            Spacer()
        }
    }
    
    // MARK: - Empty View
    private var emptyView: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "bell.slash")
                .font(.system(size: 50))
                .foregroundColor(.gray.opacity(0.5))
            
            Text("No activity yet")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
            
            Text("When someone likes, reposts your Jams\nor follows you, you'll see it here.")
                .font(.system(size: 14))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Spacer()
        }
    }
    
    // MARK: - Notifications List
    private var notificationsList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                // Today
                let todayNotifs = notificationService.notifications.filter { $0.isToday }
                if !todayNotifs.isEmpty {
                    sectionHeader("Today")
                    ForEach(todayNotifs) { notification in
                        notificationRow(for: notification)
                        
                        if notification.id != todayNotifs.last?.id {
                            ElegantDivider()
                        }
                    }
                }
                
                // Yesterday
                let yesterdayNotifs = notificationService.notifications.filter { $0.isYesterday }
                if !yesterdayNotifs.isEmpty {
                    sectionHeader("Yesterday")
                        .padding(.top, todayNotifs.isEmpty ? 0 : 20)
                    ForEach(yesterdayNotifs) { notification in
                        notificationRow(for: notification)
                        
                        if notification.id != yesterdayNotifs.last?.id {
                            ElegantDivider()
                        }
                    }
                }
                
                // Earlier
                let earlierNotifs = notificationService.notifications.filter { !$0.isToday && !$0.isYesterday }
                if !earlierNotifs.isEmpty {
                    sectionHeader("Earlier")
                        .padding(.top, (todayNotifs.isEmpty && yesterdayNotifs.isEmpty) ? 0 : 20)
                    ForEach(earlierNotifs) { notification in
                        notificationRow(for: notification)
                        
                        if notification.id != earlierNotifs.last?.id {
                            ElegantDivider()
                        }
                    }
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 100)
        }
        .refreshable {
            await notificationService.fetchNotifications()
        }
    }
    
    // MARK: - Notification Row
    private func notificationRow(for notification: JamNotification) -> some View {
        NotificationRow(
            notification: notification,
            onTapProfile: {
                // Cargar usuario completo y navegar
                loadAndShowUser(userId: notification.fromUserId)
            },
            onTapJam: {
                // Navegar al jam
                selectedNotification = notification
                showJamView = true
                
                // Marcar como leída individualmente
                Task {
                    await notificationService.markAsRead(notification.notificationId)
                }
            }
        )
    }
    
    // MARK: - Load Full User Data (Optimized)
    private func loadAndShowUser(userId: String) {
        // Mostrar perfil inmediatamente con datos básicos mientras carga
        isLoadingUser = true
        
        Task {
            do {
                let doc = try await db.collection("users").document(userId).getDocument()
                
                if let data = doc.data() {
                    let user = User(
                        uid: userId,
                        email: data["email"] as? String ?? "",
                        fullName: data["fullName"] as? String ?? "",
                        username: data["username"] as? String ?? "",
                        bio: data["bio"] as? String,
                        profileImageUrl: data["profileImageUrl"] as? String,
                        bannerImageUrl: data["bannerImageUrl"] as? String,
                        joinedDate: (data["joinedDate"] as? Timestamp)?.dateValue(),
                        followingCount: data["followingCount"] as? Int ?? 0,
                        followersCount: data["followersCount"] as? Int ?? 0,
                        jamsCount: data["jamsCount"] as? Int ?? 0
                    )
                    
                    await MainActor.run {
                        self.userToShow = user
                        self.isLoadingUser = false
                        self.showUserProfile = true
                    }
                } else {
                    await MainActor.run {
                        self.isLoadingUser = false
                    }
                }
            } catch {
                print("❌ Error loading user: \(error)")
                await MainActor.run {
                    self.isLoadingUser = false
                }
            }
        }
    }
    
    // MARK: - Section Header
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .foregroundColor(.gray)
            .font(.system(size: 13, weight: .semibold))
            .textCase(.uppercase)
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
            .padding(.top, 16)
    }
}

// MARK: - Elegant Divider
struct ElegantDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.white.opacity(0.06))
            .frame(height: 0.5)
            .padding(.leading, 76)
            .padding(.vertical, 4)
    }
}

