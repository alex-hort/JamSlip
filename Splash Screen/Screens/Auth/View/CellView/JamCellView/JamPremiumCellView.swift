//
//  JamPremiumCellView.swift
//  Splash Screen
//
//  Created by Alexis Horteales Espinosa on 22/01/26.
//
import SwiftUI

struct JamPremiumCellView: View {
    let jam: Jam
    var showDeleteOption: Bool = true
    
    @ObservedObject private var audioPlayer = AudioPlayerManager.shared
    @ObservedObject private var storeKit = StoreKitManager.shared
    
    @State private var showPaywall = false // ✅ Paywall para usuarios free
    
    // ✅ Verificar si el jam tiene Spatial Audio
    private var hasSpatialAudio: Bool {
        return jam.hasSpatialAudio == true
    }
    
    // ✅ Verificar si el usuario actual puede reproducir Spatial Audio
    private var canPlaySpatialAudio: Bool {
        return storeKit.isSubscribed
    }
    
    private var isCurrentlyPlaying: Bool {
        audioPlayer.currentJam?.id == jam.id && audioPlayer.isPlaying
    }
    
    var body: some View {
        VStack(spacing: 12) {
            
            // HEADER
            ZStack {
                // Artwork desde URL
                if let artworkUrl = jam.artworkUrl, let url = URL(string: artworkUrl) {
                    CachedAsyncImage(url: url) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        defaultArtwork
                    }
                    .frame(height: 140)
                    .clipped()
                    .clipShape(
                        UnevenRoundedRectangle(
                            topLeadingRadius: 28,
                            topTrailingRadius: 28
                        )
                    )
                } else {
                    defaultArtwork
                        .frame(height: 140)
                        .clipShape(
                            UnevenRoundedRectangle(
                                topLeadingRadius: 28,
                                topTrailingRadius: 28
                            )
                        )
                }

                LinearGradient(
                    colors: [.black.opacity(0.7), .clear],
                    startPoint: .bottom,
                    endPoint: .top
                )

                // Play/Pause Button
                HStack(spacing: 12) {
                    Button {
                        handlePlayButtonTap()
                    } label: {
                        Image(systemName: isCurrentlyPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(.black)
                            .padding(18)
                            .background(.white)
                            .clipShape(Circle())
                            .shadow(radius: 8)
                    }
                }
                .padding(.leading, 16)
                .padding(.bottom, 14)
                .frame(maxHeight: .infinity, alignment: .bottom)
            }
            .overlay(alignment: .topLeading) {
                // Fecha
                Text(jam.formattedDate)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.black.opacity(0.55))
                    .clipShape(Capsule())
                    .padding(12)
            }
            .overlay(alignment: .topTrailing) {
                // Solo mostrar menú si es el dueño del jam
                if showDeleteOption {
                    Menu {
                        Button(role: .destructive) {
                            if audioPlayer.currentJam?.id == jam.id {
                                audioPlayer.stop()
                            }
                            Task {
                                try? await MyJamsService.shared.deleteJam(jam)
                            }
                        } label: {
                            Label("Eliminar", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .foregroundStyle(.white)
                            .padding(10)
                            .background(.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    .padding(10)
                }
            }

            // INFO
            VStack(alignment: .leading, spacing: 10) {
                
                // Título y duración
                HStack(alignment: .center) {
                    if isCurrentlyPlaying {
                        Image(systemName: "waveform")
                            .font(.caption)
                            .foregroundStyle(.purple)
                            .symbolEffect(.variableColor.iterative)
                    }
                    
                    Text(jam.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    
                    // ✅ Indicador Spatial Audio
                    if hasSpatialAudio {
                        HStack(spacing: 2) {
                            Image(systemName: "ear.fill")
                                .font(.system(size: 9))
                            Text("Spatial")
                                .font(.system(size: 8, weight: .semibold))
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            LinearGradient(
                                colors: [.purple.opacity(0.4), .blue.opacity(0.4)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(6)
                        .foregroundColor(.white)
                    }

                    Spacer()

                    // Duración
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption2)
                        Text(jam.formattedDuration)
                            .font(.caption.weight(.medium))
                    }
                    .foregroundStyle(.secondary)
                }
                
                // Métricas - Likes, Saves, Reposts, Plays
                HStack(spacing: 16) {
                    StatItem(icon: "heart.fill", value: jam.likesCount, color: Color(hex: "25343F"))
                    StatItem(icon: "bookmark.fill", value: jam.savesCount, color: Color(hex: "25343F"))
                    StatItem(icon: "arrow.2.squarepath", value: jam.repostsCount,color: Color(hex: "25343F"))
                    StatItem(icon: "play.fill", value: jam.playsCount, color: Color(hex: "25343F"))
                    
                    Spacer()
                }
                
                // Tags - Género y Moods
                HStack(spacing: 8) {
                    TagView(text: jam.genre)
                    if !jam.formattedMoods.isEmpty {
                        TagView(text: jam.formattedMoods)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 14)
        }
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color(.secondarySystemBackground))
                .shadow(color: .black.opacity(0.12), radius: 14, y: 6)
        )
        .padding(.horizontal)
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
    }
    
    // ✅ Manejar tap en play
    private func handlePlayButtonTap() {
        // Si el jam NO tiene Spatial Audio, reproducir normalmente
        if !hasSpatialAudio {
            if isCurrentlyPlaying {
                audioPlayer.pause()
            } else {
                audioPlayer.playJam(jam)
            }
            return
        }
        
        // Si el jam tiene Spatial Audio, verificar si el usuario puede reproducirlo
        if canPlaySpatialAudio {
            // Usuario premium → reproducir
            if isCurrentlyPlaying {
                audioPlayer.pause()
            } else {
                audioPlayer.playJam(jam)
            }
        } else {
            // Usuario free → mostrar paywall
            showPaywall = true
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
    }
    
    private var defaultArtwork: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [.purple.opacity(0.6), .blue.opacity(0.4)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                Image(systemName: "music.note")
                    .font(.system(size: 40))
                    .foregroundColor(.white.opacity(0.5))
            )
    }
}





