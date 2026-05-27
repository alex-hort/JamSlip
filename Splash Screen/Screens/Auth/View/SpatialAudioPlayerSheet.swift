//
//  SpatialAudioPlayerSheet.swift
//  Splash Screen
//
//  Created by Alexis Horteales Espinosa on 04/02/26.
//
import SwiftUI
import Combine
import RealityKit

/// Sheet con reproductor Spatial Audio usando RealityKit
/// Con controles de anterior/siguiente y progress bar funcional
struct SpatialAudioPlayerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var audioVM = SpatialAudioViewModel.shared
    
    // ✅ NUEVO: Estados para drag optimizado
    @State private var isDragging = false
    @State private var dragValue: Double = 0
    @GestureState private var isActivelyDragging = false
    
    // Computed from audioVM
    private var title: String {
        audioVM.currentTrack?.title ?? audioVM.currentJam?.title ?? "Unknown"
    }
    
    private var artist: String {
        if let track = audioVM.currentTrack {
            return "@\(track.user.handle)"
        } else if let jam = audioVM.currentJam {
            return "@\(jam.username)"
        }
        return ""
    }
    
    private var artworkURL: String? {
        audioVM.currentTrack?.imageURL ?? audioVM.currentJam?.artworkUrl
    }
    
    // ✅ OPTIMIZADO: Tiempo que se muestra en el slider
    private var displayTime: Double {
        isDragging ? dragValue : audioVM.currentTime
    }
    
    var body: some View {
        ZStack {
            backgroundView
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    // Artwork
                    artworkView
                        .padding(.top, 24)
                    
                    // Title & Artist
                    infoView
                    
                    // Loading indicator
                    if audioVM.isLoading {
                        loadingView
                    }
                    
                    // ✅ Progress bar OPTIMIZADO
                    progressView
                        .padding(.horizontal, 8)
                    
                    // Playback controls with prev/next
                    playbackControls
                    
                    // Spatial Audio Controls (3 sliders)
                    spatialControlsView
                        .padding(.top, 8)
                        .padding(.bottom, 40)
                }
                .frame(maxWidth: 360)
                .padding(.horizontal, 20)
            }
        }
    }
    
    // MARK: - Background
    private var backgroundView: some View {
        ZStack {
            Color.black
            
            if let urlString = artworkURL, let url = URL(string: urlString) {
                CachedAsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .blur(radius: 60)
                        .opacity(0.4)
                } placeholder: {
                    Color.black
                }
                .id(urlString)
            }
            
            LinearGradient(
                colors: [.black.opacity(0.3), .black.opacity(0.9)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.3), value: artworkURL)
    }
    
    // MARK: - Artwork
    private var artworkView: some View {
        Group {
            if let urlString = artworkURL, let url = URL(string: urlString) {
                CachedAsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    artworkPlaceholder
                }
                .id(urlString)
            } else {
                artworkPlaceholder
            }
        }
        .frame(width: 220, height: 220)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.5), radius: 20, y: 10)
        .animation(.easeInOut(duration: 0.3), value: artworkURL)
    }
    
    private var artworkPlaceholder: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(
                LinearGradient(
                    colors: [.purple.opacity(0.6), .blue.opacity(0.4)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                Image(systemName: "music.note")
                    .font(.system(size: 60))
                    .foregroundColor(.white.opacity(0.5))
            )
    }
    
    // MARK: - Info
    private var infoView: some View {
        VStack(alignment: .leading, spacing: 6) {
            MarqueeText(
                text: title,
                font: .custom("AvenirNext-Bold", size: 26),
                speed: 35,
                delay: 1.5
            )
            .frame(maxWidth: .infinity, alignment: .leading)
            
            MarqueeText(
                text: artist,
                font: .custom("AvenirNext-Regular", size: 16),
                speed: 30,
                delay: 1.5
            )
            .opacity(0.75)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: 280)
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        HStack(spacing: 12) {
            ProgressView()
                .tint(.cyan)
            
            Text("Loading...")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - ✅ Progress OPTIMIZADO (como Spotify)
    private var progressView: some View {
        VStack(spacing: 10) {
            // Custom Slider
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    Capsule()
                        .fill(Color.white.opacity(0.2))
                        .frame(height: 4)
                    
                    // Progress fill
                    Capsule()
                        .fill(Color.white)
                        .frame(width: progressWidth(in: geometry.size.width), height: 4)
                    
                    // Drag thumb
                    if isDragging {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 14, height: 14)
                            .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
                            .offset(x: progressWidth(in: geometry.size.width) - 7)
                    }
                }
                .frame(height: 28)
                .contentShape(Rectangle())
                .highPriorityGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            // ✅ Marcar que estamos arrastrando
                            if !isDragging {
                                isDragging = true
                            }
                            
                            // ✅ Calcular nueva posición
                            let percent = max(0, min(1, value.location.x / geometry.size.width))
                            let newTime = percent * audioVM.duration
                            
                            // ✅ Actualizar dragValue para vista
                            dragValue = newTime
                            
                            print("🎯 Dragging: \(Int(newTime))s / \(Int(audioVM.duration))s")
                        }
                        .onEnded { _ in
                            print("✅ Seek to: \(Int(dragValue))s")
                            
                            // ✅ Hacer seek
                            audioVM.seek(to: dragValue)
                            
                            // ✅ Esperar un poquito para suavidad
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                isDragging = false
                            }
                        }
                )
            }
            .frame(height: 28)
            
            HStack {
                Text(formatTime(displayTime))
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                    .monospacedDigit()
                
                Spacer()
                
                Text(formatTime(audioVM.duration))
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: 360)
    }
    
    // ✅ NUEVO: Calcular ancho de progreso
    private func progressWidth(in totalWidth: CGFloat) -> CGFloat {
        guard audioVM.duration > 0 else { return 0 }
        let progress = displayTime / audioVM.duration
        return totalWidth * CGFloat(progress)
    }
    
    // MARK: - Playback Controls
    private var playbackControls: some View {
        HStack(spacing: 40) {
            // Previous
            Button {
                Task {
                    await audioVM.playPrevious()
                }
            } label: {
                Image(systemName: "backward.fill")
                    .font(.system(size: 28))
                    .foregroundColor(audioVM.hasPrevious ? .white : .white.opacity(0.3))
            }
            .disabled(!audioVM.hasPrevious || audioVM.isLoading)
            
            // Play/Pause
            Button {
                audioVM.togglePlayPause()
            } label: {
                ZStack {
                    Circle()
                        .fill(.white)
                        .frame(width: 70, height: 70)
                    
                    if audioVM.isLoading {
                        ProgressView()
                            .tint(.black)
                    } else {
                        Image(systemName: audioVM.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.black)
                            .offset(x: audioVM.isPlaying ? 0 : 2)
                    }
                }
            }
            .disabled(audioVM.isLoading)
            
            // Next
            Button {
                Task {
                    await audioVM.playNext()
                }
            } label: {
                Image(systemName: "forward.fill")
                    .font(.system(size: 28))
                    .foregroundColor(audioVM.hasNext ? .white : .white.opacity(0.3))
            }
            .disabled(!audioVM.hasNext || audioVM.isLoading)
        }
    }
    
    // MARK: - Spatial Controls
    private var spatialControlsView: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 4) {
                Text("Spatial Audio")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text("Reverb Environment")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            // Sliders
            VStack(spacing: 18) {
                DecibelSlider(name: "Gain", value: $audioVM.gain)
                    .onChange(of: audioVM.gain) { _, _ in
                        audioVM.updateAudioProperties()
                    }
                
                DecibelSlider(name: "Direct Level", value: $audioVM.directLevel)
                    .onChange(of: audioVM.directLevel) { _, _ in
                        audioVM.updateAudioProperties()
                    }
                
                DecibelSlider(name: "Reverb Level", value: $audioVM.reverbLevel)
                    .onChange(of: audioVM.reverbLevel) { _, _ in
                        audioVM.updateAudioProperties()
                    }
            }
            
            Divider().opacity(0.4)
            
            // Tips
            VStack(alignment: .leading, spacing: 6) {
                Text("Tips")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                
                Text("Move around to feel directionality")
                Text("Distance affects reverb intensity")
                Text("Use headphones for best experience")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 16)
        .frame(maxWidth: 360)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .shadow(color: .black.opacity(0.25), radius: 20, y: 10)
    }
    
    // MARK: - Helpers
    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite else { return "0:00" }
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

// MARK: - Decibel Slider
struct DecibelSlider: View {
    let name: String
    @Binding var value: Audio.Decibel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                
                Spacer()
                
                Text("\(Int(value)) dB")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .monospacedDigit()
                    .foregroundStyle(.cyan)
                    .frame(width: 60, alignment: .trailing)
            }
            
            Slider(value: $value, in: -60...0, step: 1)
                .tint(.cyan)
                .frame(height: 28)
        }
    }
}
