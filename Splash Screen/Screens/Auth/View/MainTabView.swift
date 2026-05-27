//
//  MainTabView.swift
//  Splash Screen
//
//  Created by Alexis Horteales Espinosa on 08/01/26.
//
import SwiftUI
import RealityKit

struct MainTabView: View {

    @State private var activeTab: TabModel = .home
    @StateObject private var notificationService = NotificationService.shared
    @ObservedObject private var spatialAudio = SpatialAudioViewModel.shared
    
    @State private var showSpatialPlayerSheet = false
    
    var body: some View {
        ZStack {
            // RealityView PERSISTENTE para spatial audio (invisible)
            RealityView { content in
                content.add(spatialAudio.reverbEntity)
            }
            .frame(width: 1, height: 1)
            .opacity(0)
            .allowsHitTesting(false)
            
            // Main content
            VStack(spacing: 0) {
                // Content
                ZStack {
                    HomeView()
                        .opacity(activeTab == .home ? 1 : 0)
                        .allowsHitTesting(activeTab == .home)

                    SearchView()
                        .opacity(activeTab == .search ? 1 : 0)
                        .allowsHitTesting(activeTab == .search)

                    NotificationsView()
                        .opacity(activeTab == .notifications ? 1 : 0)
                        .allowsHitTesting(activeTab == .notifications)

                    ProfileView()
                        .opacity(activeTab == .profile ? 1 : 0)
                        .allowsHitTesting(activeTab == .profile)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // Mini Player
                if !spatialAudio.queue.isEmpty {
                    miniPlayer
                }
                
                // Tab Bar
                customTabBar
            }
        }
        .background(Color.black)
        .ignoresSafeArea(.keyboard)
        .onChange(of: activeTab) { oldValue, newValue in
            if oldValue == .home && newValue != .home {
                AudioPlayerManager.shared.pause()
            }
            
            if newValue == .notifications {
                Task {
                    await notificationService.markAllAsRead()
                }
            }
        }
        .task {
            await notificationService.fetchNotifications()
            notificationService.startListening()
        }
        .sheet(isPresented: $showSpatialPlayerSheet) {
            SpatialAudioPlayerSheet()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
        }
    }
    
    // MARK: - Mini Player
    private var miniPlayer: some View {
        Button {
            showSpatialPlayerSheet = true
        } label: {
            HStack(spacing: 12) {
                // Artwork
                Group {
                    if let urlString = spatialAudio.currentTrack?.imageURL ?? spatialAudio.currentJam?.artworkUrl,
                       let url = URL(string: urlString) {
                        CachedAsyncImage(url: url) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Rectangle()
                                .fill(Color.purple.opacity(0.3))
                        }
                        .id(urlString)
                    } else {
                        Rectangle()
                            .fill(Color.purple.opacity(0.3))
                            .overlay(
                                Image(systemName: "music.note")
                                    .foregroundColor(.white.opacity(0.5))
                            )
                    }
                }
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                
                // Info
                VStack(alignment: .leading, spacing: 2) {
                    Text(spatialAudio.currentTrack?.title ?? spatialAudio.currentJam?.title ?? "")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Text(spatialAudio.currentTrack?.user.name ?? spatialAudio.currentJam?.username ?? "")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Waveform
                if spatialAudio.isPlaying {
                    Image(systemName: "waveform")
                        .font(.title3)
                        .foregroundColor(.cyan)
                        .symbolEffect(.variableColor.iterative, options: .repeating)
                }
                
                // Previous
                Button {
                    Task { await spatialAudio.playPrevious() }
                } label: {
                    Image(systemName: "backward.fill")
                        .font(.body)
                        .foregroundColor(spatialAudio.hasPrevious ? .white : .gray)
                }
                .disabled(!spatialAudio.hasPrevious)
                
                // Play/Pause
                Button {
                    spatialAudio.togglePlayPause()
                } label: {
                    Image(systemName: spatialAudio.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                }
                
                // Next
                Button {
                    Task { await spatialAudio.playNext() }
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.body)
                        .foregroundColor(spatialAudio.hasNext ? .white : .gray)
                }
                .disabled(!spatialAudio.hasNext)
                
                // Close
                Button {
                    Task { await spatialAudio.stop() }
                } label: {
                    Image(systemName: "xmark")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .frame(width: 28, height: 28)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.1))
            )
            .padding(.horizontal, 12)
            .padding(.bottom, 4)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Tab Bar
    private var customTabBar: some View {
        HStack {
            ForEach(TabModel.allCases, id: \.self) { tab in
                Spacer()
                tabButton(tab)
                Spacer()
            }
        }
        .padding(.top, 12)
        .padding(.bottom, 28)
        .background(Color.black)
    }

    private func tabButton(_ tab: TabModel) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                activeTab = tab
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            VStack(spacing: 4) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: tab.rawValue)
                        .font(.system(size: 24))
                        .environment(\.symbolVariants, activeTab == tab ? .fill : .none)
                    
                    if tab == .notifications && notificationService.unreadCount > 0 {
                        ZStack {
                            Circle()
                                .fill(Color.purple)
                                .frame(width: 16, height: 16)
                            
                            Text(notificationService.unreadCount > 9 ? "9+" : "\(notificationService.unreadCount)")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .offset(x: 8, y: -6)
                    }
                }

                Text(tab.title)
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(activeTab == tab ? .white : .gray)
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(AuthViewModel())
}

