//
//  JamViews.swift
//  Splash Screen
//
//  Created by Alexis Horteales Espinosa on 22/01/26.

import SwiftUI

struct JamViews: View {
    let isSelected: Bool
    
    @State private var currentIndex: Int = 0
    @StateObject private var jamsService = MyJamsService.shared
    @StateObject private var repostService = JamRepostService.shared
    @ObservedObject private var audioPlayer = AudioPlayerManager.shared
    
    @State private var repostCheckTimer: Timer?
    @State private var loadedRepostsForJams: Set<String> = []
    
    private let preloadThreshold = 5
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if jamsService.isLoading && jamsService.feedJams.isEmpty {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.white)
                    Text("Cargando jams...")
                        .foregroundColor(.white.opacity(0.6))
                }
            } else if jamsService.feedJams.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 60))
                        .foregroundColor(.white.opacity(0.3))
                    
                    Text("No Jams available")
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.6))
                    
                    Text("Be the first to upload a Jam")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.4))
                }
            } else {
                GeometryReader { geo in
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 0) {
                            ForEach(Array(jamsService.feedJams.enumerated()), id: \.element.id) { index, jam in
                                ZStack {
                                    // Buscar si este jam tiene un repost asociado
                                    let repostInfo = jamsService.getRepostInfo(for: jam.id)
                                    
                                    JamFeedCardView(jam: jam, repostInfo: repostInfo)
                                    
                                    // Reposts flotantes
                                    let reposts = jamsService.getVisibleReposts(for: jam.id)
                                    if !reposts.isEmpty {
                                        FloatingJamRepostsView(
                                            reposts: reposts,
                                            cardWidth: geo.size.width - 40,
                                            cardHeight: geo.size.height - 80
                                        )
                                    }
                                }
                                .padding(.horizontal, 20)
                                .padding(.top, 10)
                                .padding(.bottom, 50)
                                .frame(
                                    width: geo.size.width,
                                    height: geo.size.height
                                )
                                .scrollTransition { content, phase in
                                    content
                                        .scaleEffect(
                                            x: phase.isIdentity ? 1.0 : 0.85,
                                            y: phase.isIdentity ? 1.0 : 0.85
                                        )
                                        .rotation3DEffect(
                                            .degrees(phase.value * -15),
                                            axis: (x: 0, y: 1, z: 0),
                                            perspective: 0.5
                                        )
                                        .opacity(phase.isIdentity ? 1.0 : 0.7)
                                        .blur(radius: phase.isIdentity ? 0 : 3)
                                }
                                .onAppear {
                                    handleJamAppear(index: index, jam: jam)
                                }
                            }
                        }
                        .scrollTargetLayout()
                    }
                    .scrollTargetBehavior(.paging)
                    .scrollPosition(id: Binding(
                        get: {
                            jamsService.feedJams.indices.contains(currentIndex) ? jamsService.feedJams[currentIndex].id : nil
                        },
                        set: { newId in
                            if let newId = newId,
                               let index = jamsService.feedJams.firstIndex(where: { $0.id == newId }) {
                                if currentIndex != index {
                                    currentIndex = index
                                    if isSelected {
                                        audioPlayer.playJam(jamsService.feedJams[index])
                                    }
                                }
                            }
                        }
                    ))
                }
            }
        }
        .ignoresSafeArea()
        .onChange(of: isSelected) { _, newValue in
            if newValue {
                if !jamsService.feedJams.isEmpty && jamsService.feedJams.indices.contains(currentIndex) {
                    audioPlayer.playJam(jamsService.feedJams[currentIndex])
                }
                startRepostTimer()
            } else {
                audioPlayer.pause()
                stopRepostTimer()
            }
        }
        .onAppear {
            if isSelected {
                startRepostTimer()
            }
        }
        .onDisappear {
            stopRepostTimer()
        }
    }
    
    // MARK: - Handle Jam Appear
    private func handleJamAppear(index: Int, jam: Jam) {
        let remaining = jamsService.feedJams.count - index - 1
        
        // Cargar más cuando quedan pocos jams
        if remaining <= preloadThreshold && !jamsService.isLoading {
            print("🔄 Jams restantes: \(remaining), cargando más...")
            Task {
                await jamsService.loadMoreJams()
            }
        }
        
        // Insertar reposts pendientes cada 4 jams
        if index > 0 && index % 4 == 0 {
            jamsService.insertPendingRepost(after: index)
        }
        
        // Cargar reposts para este jam si no los hemos cargado
        if !loadedRepostsForJams.contains(jam.id) {
            loadedRepostsForJams.insert(jam.id)
            loadRepostsForJam(jam)
        }
    }
    
    // MARK: - Load Reposts for Jam
    private func loadRepostsForJam(_ jam: Jam) {
        Task {
            let reposts = await repostService.fetchRepostsForJam(jam.id)
            
            await MainActor.run {
                for repost in reposts {
                    // Verificar que no esté duplicado
                    if !jamsService.visibleReposts.contains(where: { $0.id == repost.id }) {
                        let visible = repostService.toVisibleRepost(repost)
                        jamsService.visibleReposts.append(visible)
                    }
                }
                
                if !reposts.isEmpty {
                    print("💬 \(reposts.count) reposts cargados para: \(jam.title)")
                }
            }
        }
    }
    
    // MARK: - Repost Timer
    private func startRepostTimer() {
        repostCheckTimer?.invalidate()
        repostCheckTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            checkAndInsertNewReposts()
        }
    }
    
    private func stopRepostTimer() {
        repostCheckTimer?.invalidate()
        repostCheckTimer = nil
    }
    
    private func checkAndInsertNewReposts() {
        guard !repostService.pendingReposts.isEmpty else { return }
        jamsService.insertPendingRepost(after: currentIndex)
    }
}



















