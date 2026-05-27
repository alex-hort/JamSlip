//
//  JamGridItem.swift
//  Splash Screen
//
//  Created by Alexis Horteales Espinosa on 14/01/26.
//
import SwiftUI

// MARK: - Audius Track Grid Item
/// Grid item para tracks de Audius - usado en SavedJamsView y LikedJamsView
/// ✅ TODOS los tracks tienen Spatial Audio disponible para usuarios premium
struct JamGridItem: View {
    let track: AudiusTrack
    let showLikesCount: Bool
    
    // Queue context
    var allTracks: [AudiusTrack] = []
    
    @StateObject private var audioPlayer = AudioPlayerManager.shared
    @StateObject private var spatialPlayer = SpatialAudioViewModel.shared
    @StateObject private var userJamsService = UserJamsService.shared
    @ObservedObject private var storeKit = StoreKitManager.shared
    
    @State private var showSpatialSheet = false
    @State private var showPaywall = false
    @State private var pendingPlayAfterPaywall = false
    
    private var isPlaying: Bool {
        (audioPlayer.currentTrack?.id == track.id && audioPlayer.isPlaying) ||
        (spatialPlayer.currentTrack?.id == track.id && spatialPlayer.isPlaying)
    }
    
    private var displayCount: String {
        let count = showLikesCount
            ? userJamsService.getLikesCount(for: track.id)
            : userJamsService.getSavesCount(for: track.id)
        
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        } else {
            return "\(count)"
        }
    }
    
    var body: some View {
        GeometryReader { reader in
            ZStack {
                // Artwork
                CachedAsyncImage(url: URL(string: track.imageURL ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: reader.size.width, height: reader.size.height)
                        .clipped()
                        .overlay(Color.black.opacity(isPlaying ? 0.5 : 0.3))
                } placeholder: {
                    Rectangle()
                        .fill(LinearGradient(
                            colors: [.purple.opacity(0.5), .blue.opacity(0.5)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .overlay {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(0.7)
                        }
                }
                
                // ✅ Badge de Spatial Audio: SIEMPRE disponible para premium
                if storeKit.isVerified && storeKit.isSubscribed {
                    VStack {
                        HStack {
                            HStack(spacing: 4) {
                                Text("SPATIAL AUDIO")
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                    .tracking(0.6)
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                Capsule()
                                    .fill(.ultraThinMaterial)
                                    .background(
                                        Capsule()
                                            .fill(
                                                LinearGradient(
                                                    colors: [
                                                        Color.black.opacity(0.85),
                                                        Color.black.opacity(0.6)
                                                    ],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                    )
                            )
                            .overlay(
                                Capsule()
                                    .stroke(Color.white.opacity(0.18), lineWidth: 0.5)
                            )
                            .shadow(
                                color: Color.black.opacity(
                                    UITraitCollection.current.userInterfaceStyle == .dark ? 0.5 : 0.25
                                ),
                                radius: 8,
                                x: 0,
                                y: 4
                            )
                            .padding(6)

                            Spacer()
                        }
                        Spacer()
                    }
                }
                
                // Playing indicator
                if isPlaying {
                    Image(systemName: "waveform")
                        .font(.system(size: 30))
                        .foregroundColor(.white)
                        .symbolEffect(.variableColor.iterative, options: .repeating)
                }
                
                // Count badge
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        HStack(spacing: 0) {
                            Image(systemName: showLikesCount ? "heart.fill" : "bookmark.fill")
                                .foregroundColor(.primary)
                                .imageScale(.small)
                                .padding(.leading, 4)
                            
                            Spacer(minLength: 12)
                            
                            Text(displayCount)
                                .font(.system(size: 15))
                                .fontWeight(.heavy)
                                .foregroundStyle(.primary)
                        }
                        .padding(4)
                        .background(Color.white.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .padding(6)
                }
            }
            .frame(width: reader.size.width, height: reader.size.height)
            .background(Color.black)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: Color.white.opacity(0.1), radius: 10, y: 5)
            .onTapGesture {
                handleTap()
            }
        }
        .frame(height: 150)
        .sheet(isPresented: $showSpatialSheet) {
            SpatialAudioPlayerSheet()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
        }
        .sheet(isPresented: $showPaywall, onDismiss: handlePaywallDismiss) {
            PaywallView()
        }
        .task {
            await userJamsService.fetchGlobalCounts(for: track.id)
            if let imageURL = track.imageURL {
                await ImageCacheService.shared.preloadImage(from: imageURL)
            }
        }
    }
    
    // ✅ LÓGICA: Usuario premium siempre usa Spatial Audio
//    private func handleTap() {
//        // Si está reproduciendo, pausar
//        if isPlaying {
//            if audioPlayer.currentTrack?.id == track.id {
//                audioPlayer.pause()
//            } else if spatialPlayer.currentTrack?.id == track.id {
//                spatialPlayer.pause()
//            }
//            return
//        }
//        
//        // ✅ Verificar si usuario está verificado
//        guard storeKit.isVerified else {
//            print("⏳ Esperando verificación...")
//            return
//        }
//        
//        // ✅ Si es premium, SIEMPRE abrir Spatial Audio Player
//        if storeKit.isSubscribed {
//            openSpatialPlayer()
//        } else {
//            // Usuario free - mostrar paywall
//            pendingPlayAfterPaywall = true
//            showPaywall = true
//        }
//    }
    
    private func handleTap() {
        // Si está reproduciendo ESTE track, pausar
        if isPlaying {
            if audioPlayer.currentTrack?.id == track.id {
                audioPlayer.pause()
            } else if spatialPlayer.currentTrack?.id == track.id {
                spatialPlayer.pause()
            }
            return
        }
        
        guard storeKit.isVerified else {
            print("⏳ Esperando verificación...")
            return
        }
        
        // ✅ CRÍTICO: Detener TODO el audio antes de reproducir
        Task {
            await stopAllAudio()
            
            if storeKit.isSubscribed {
                openSpatialPlayer()
            } else {
                pendingPlayAfterPaywall = true
                showPaywall = true
            }
        }
    }
    // ✅ NUEVA FUNCIÓN: Detener todo el audio
    private func stopAllAudio() async {
        // Detener audio normal
        await MainActor.run {
            audioPlayer.stop()
        }
        
        // Detener spatial audio
        await spatialPlayer.stop()
        
        // Pequeña pausa para asegurar que se detuvo
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 segundos
    }
    
    private func handlePaywallDismiss() {
        guard pendingPlayAfterPaywall else { return }
        pendingPlayAfterPaywall = false
        
        if storeKit.isSubscribed {
            // Ahora es premium - abrir Spatial Audio
            openSpatialPlayer()
        } else {
            // No pagó - reproducir audio normal
            playNormalAudio()
        }
    }
    
//    private func openSpatialPlayer() {
//        if !allTracks.isEmpty {
//            let startIndex = allTracks.firstIndex(where: { $0.id == track.id }) ?? 0
//            spatialPlayer.setQueue(tracks: allTracks, startIndex: startIndex)
//        } else {
//            spatialPlayer.setQueue(tracks: [track], startIndex: 0)
//        }
//        
//        showSpatialSheet = true
//        
//        Task {
//            await spatialPlayer.playCurrent()
//        }
//    }
    private func openSpatialPlayer() {
        // Asegurarse que no haya audio normal
        audioPlayer.stop()
        
        if !allTracks.isEmpty {
            let startIndex = allTracks.firstIndex(where: { $0.id == track.id }) ?? 0
            spatialPlayer.setQueue(tracks: allTracks, startIndex: startIndex)
        } else {
            spatialPlayer.setQueue(tracks: [track], startIndex: 0)
        }
        
        showSpatialSheet = true
        
        Task {
            await spatialPlayer.playCurrent()
        }
    }
    
//    private func playNormalAudio() {
//        audioPlayer.playAutomatically(track: track)
//        print("🎵 Reproduciendo track normal: \(track.title)")
//    }
    
    //  REEMPLAZA playNormalAudio() con esta versión:
    private func playNormalAudio() {
        // Detener spatial audio primero
        Task {
            await spatialPlayer.stop()
            
            // Luego reproducir audio normal
            await MainActor.run {
                audioPlayer.playAutomatically(track: track)
                print("🎵 Reproduciendo track normal: \(track.title)")
            }
        }
    }
}

// MARK: - Premium Jam Grid Item
/// Grid item para Jams Premium - usado en SavedJamsView y LikedJamsView
/// ✅ TODOS los jams premium tienen Spatial Audio disponible para usuarios premium
struct PremiumJamGridItem: View {
    let jam: Jam
    var showLikesCount: Bool = false
    
    // Queue context
    var allJams: [Jam] = []
    
    @ObservedObject private var audioPlayer = AudioPlayerManager.shared
    @ObservedObject private var spatialPlayer = SpatialAudioViewModel.shared
    @ObservedObject private var storeKit = StoreKitManager.shared
    
    @State private var showSpatialSheet = false
    @State private var showPaywall = false
    @State private var pendingPlayAfterPaywall = false
    
    private var isPlaying: Bool {
        (audioPlayer.currentJam?.id == jam.id && audioPlayer.isPlaying) ||
        (spatialPlayer.currentJam?.id == jam.id && spatialPlayer.isPlaying)
    }
    
    private var displayCount: String {
        let count = showLikesCount ? jam.likesCount : jam.savesCount
        
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        } else {
            return "\(count)"
        }
    }
    
    var body: some View {
        GeometryReader { reader in
            ZStack {
                // Artwork
                if let artworkUrl = jam.artworkUrl, let url = URL(string: artworkUrl) {
                    CachedAsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: reader.size.width, height: reader.size.height)
                            .clipped()
                            .overlay(Color.black.opacity(isPlaying ? 0.5 : 0.3))
                    } placeholder: {
                        defaultPlaceholder
                    }
                } else {
                    defaultPlaceholder
                }
                
                // ✅ Badge de Spatial Audio: SIEMPRE disponible para premium
                if storeKit.isVerified && storeKit.isSubscribed {
                    VStack {
                        HStack {
                            HStack(spacing: 4) {
                                Text("SPATIAL AUDIO")
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                    .tracking(0.6)
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                Capsule()
                                    .fill(.ultraThinMaterial)
                                    .background(
                                        Capsule()
                                            .fill(
                                                LinearGradient(
                                                    colors: [
                                                        Color.black.opacity(0.85),
                                                        Color.black.opacity(0.65)
                                                    ],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                    )
                            )
                            .overlay(
                                Capsule()
                                    .stroke(Color.white.opacity(0.18), lineWidth: 0.5)
                            )
                            .shadow(
                                color: Color.black.opacity(
                                    UITraitCollection.current.userInterfaceStyle == .dark ? 0.5 : 0.25
                                ),
                                radius: 8,
                                x: 0,
                                y: 4
                            )
                            .padding(6)

                            Spacer()
                        }
                        Spacer()
                    }
                }
                
                // Playing indicator
                if isPlaying {
                    Image(systemName: "waveform")
                        .font(.system(size: 30))
                        .foregroundColor(.white)
                        .symbolEffect(.variableColor.iterative, options: .repeating)
                }
                
                // Count badge
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        HStack(spacing: 0) {
                            Image(systemName: showLikesCount ? "heart.fill" : "bookmark.fill")
                                .foregroundColor(.primary)
                                .imageScale(.small)
                                .padding(.leading, 4)
                            
                            Spacer(minLength: 12)
                            
                            Text(displayCount)
                                .font(.system(size: 15))
                                .fontWeight(.heavy)
                                .foregroundStyle(.primary)
                        }
                        .padding(4)
                        .background(Color.white.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .padding(6)
                }
            }
            .frame(width: reader.size.width, height: reader.size.height)
            .background(Color.black)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: Color.white.opacity(0.1), radius: 10, y: 5)
            .onTapGesture {
                handleTap()
            }
        }
        .frame(height: 150)
        .sheet(isPresented: $showSpatialSheet) {
            SpatialAudioPlayerSheet()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
        }
        .sheet(isPresented: $showPaywall, onDismiss: handlePaywallDismiss) {
            PaywallView()
        }
    }
    
    // ✅ LÓGICA: Usuario premium siempre usa Spatial Audio
//    private func handleTap() {
//        // Si está reproduciendo, pausar
//        if isPlaying {
//            if audioPlayer.currentJam?.id == jam.id {
//                audioPlayer.pause()
//            } else if spatialPlayer.currentJam?.id == jam.id {
//                spatialPlayer.pause()
//            }
//            return
//        }
//        
//        // ✅ Verificar si usuario está verificado
//        guard storeKit.isVerified else {
//            print("⏳ Esperando verificación...")
//            return
//        }
//        
//        // ✅ Si es premium, SIEMPRE abrir Spatial Audio Player
//        if storeKit.isSubscribed {
//            openSpatialPlayer()
//        } else {
//            // Usuario free - mostrar paywall
//            pendingPlayAfterPaywall = true
//            showPaywall = true
//        }
//    }
    // ✅ REEMPLAZA handleTap() con esta versión:
    private func handleTap() {
        // Si está reproduciendo ESTE jam, pausar
        if isPlaying {
            if audioPlayer.currentJam?.id == jam.id {
                audioPlayer.pause()
            } else if spatialPlayer.currentJam?.id == jam.id {
                spatialPlayer.pause()
            }
            return
        }
        
        guard storeKit.isVerified else {
            print("⏳ Esperando verificación...")
            return
        }
        
        // ✅ CRÍTICO: Detener TODO el audio antes de reproducir
        Task {
            await stopAllAudio()
            
            if storeKit.isSubscribed {
                openSpatialPlayer()
            } else {
                pendingPlayAfterPaywall = true
                showPaywall = true
            }
        }
    }
    
    // ✅ NUEVA FUNCIÓN: Detener todo el audio
    private func stopAllAudio() async {
        // Detener audio normal
        await MainActor.run {
            audioPlayer.stop()
        }
        
        // Detener spatial audio
        await spatialPlayer.stop()
        
        // Pequeña pausa para asegurar que se detuvo
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 segundos
    }
    
    private func handlePaywallDismiss() {
        guard pendingPlayAfterPaywall else { return }
        pendingPlayAfterPaywall = false
        
        if storeKit.isSubscribed {
            // Ahora es premium - abrir Spatial Audio
            openSpatialPlayer()
        } else {
            // No pagó - reproducir audio normal
            playNormalAudio()
        }
    }
    
//    private func openSpatialPlayer() {
//        if !allJams.isEmpty {
//            let startIndex = allJams.firstIndex(where: { $0.id == jam.id }) ?? 0
//            spatialPlayer.setQueue(jams: allJams, startIndex: startIndex)
//        } else {
//            spatialPlayer.setQueue(jams: [jam], startIndex: 0)
//        }
//        
//        showSpatialSheet = true
//        
//        Task {
//            await spatialPlayer.playCurrent()
//        }
//    }
    // ✅ REEMPLAZA openSpatialPlayer() con esta versión:
    private func openSpatialPlayer() {
        // Asegurarse que no haya audio normal
        audioPlayer.stop()
        
        if !allJams.isEmpty {
            let startIndex = allJams.firstIndex(where: { $0.id == jam.id }) ?? 0
            spatialPlayer.setQueue(jams: allJams, startIndex: startIndex)
        } else {
            spatialPlayer.setQueue(jams: [jam], startIndex: 0)
        }
        
        showSpatialSheet = true
        
        Task {
            await spatialPlayer.playCurrent()
        }
    }
//    
//    private func playNormalAudio() {
//        audioPlayer.playJam(jam)
//        print("🎵 Reproduciendo jam normal: \(jam.title)")
//    }
    
    // ✅ REEMPLAZA playNormalAudio() con esta versión:
    private func playNormalAudio() {
        // Detener spatial audio primero
        Task {
            await spatialPlayer.stop()
            
            // Luego reproducir audio normal
            await MainActor.run {
                audioPlayer.playJam(jam)
                print("🎵 Reproduciendo jam normal: \(jam.title)")
            }
        }
    }
    
    private var defaultPlaceholder: some View {
        Rectangle()
            .fill(LinearGradient(
                colors: [.purple.opacity(0.5), .blue.opacity(0.5)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ))
            .overlay {
                Image(systemName: "music.note")
                    .font(.system(size: 30))
                    .foregroundColor(.white.opacity(0.5))
            }
            .overlay(Color.black.opacity(isPlaying ? 0.5 : 0.3))
    }
}
