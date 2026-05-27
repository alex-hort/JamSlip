//
//  AudioPlayerManager.swift
//  Splash Screen
//
//  Created by Alexis Horteales Espinosa on 14/01/26.
//
import Foundation
import AVFoundation
import Combine

class AudioPlayerManager: ObservableObject {
    static let shared = AudioPlayerManager()
    
    @Published var isPlaying = false
    @Published var currentTrack: AudiusTrack?
    @Published var currentJam: Jam?
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    
    var currentPlayingId: String? {
        currentTrack?.id ?? currentJam?.id
    }
    
    private var player: AVPlayer?
    private var timeObserver: Any?
    
    private init() {
        setupAudioSession()
        setupNotifications()
    }
    
    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
        } catch {
            print("AudioSession error:", error)
        }
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerDidFinishPlaying(_:)),
            name: .AVPlayerItemDidPlayToEndTime,
            object: nil
        )
    }
    
    @objc private func playerDidFinishPlaying(_ notification: Notification) {
        guard
            let finishedItem = notification.object as? AVPlayerItem,
            finishedItem == player?.currentItem
        else { return }
        
        isPlaying = false
        currentTime = 0
    }
    
    // MARK: - Stop Spatial Audio
    private func stopSpatialAudioIfNeeded() {
        SpatialAudioViewModel.shared.stopIfPlaying()
    }
    
    // MARK: - Reproducir Jam
    func playJam(_ jam: Jam) {
        stopSpatialAudioIfNeeded()
        
        if currentJam?.id == jam.id {
            if isPlaying {
                pause()
            } else {
                resume()
            }
            return
        }
        
        guard let url = URL(string: jam.audioUrl) else {
            print("URL de audio inválida")
            return
        }
        
        removeTimeObserver()
        
        if let player = player {
            player.pause()
            player.replaceCurrentItem(with: nil)
        }
        
        isPlaying = false
        currentTrack = nil
        currentJam = jam
        currentTime = 0
        duration = Double(jam.duration)
        
        let asset = AVURLAsset(url: url, options: [AVURLAssetPreferPreciseDurationAndTimingKey: false])
        let playerItem = AVPlayerItem(asset: asset)
        playerItem.preferredForwardBufferDuration = 2.0
        
        let newPlayer = AVPlayer(playerItem: playerItem)
        newPlayer.volume = 1.0
        newPlayer.automaticallyWaitsToMinimizeStalling = false
        
        self.player = newPlayer
        
        setupTimeObserver()
        
        DispatchQueue.main.async {
            newPlayer.playImmediately(atRate: 1.0)
            self.isPlaying = true
        }
    }
    
    func togglePlayPause(for jam: Jam) {
        if currentJam?.id == jam.id {
            if isPlaying {
                pause()
            } else {
                resume()
            }
        } else {
            playJam(jam)
        }
    }
    
    func isPlayingJam(_ jam: Jam) -> Bool {
        return currentJam?.id == jam.id && isPlaying
    }
    
    // MARK: - Reproducción automática (AudiusTrack)
    func playAutomatically(track: AudiusTrack) {
        stopSpatialAudioIfNeeded()
        
        if currentTrack?.id == track.id {
            return
        }
        
        let url = track.streamURL
        
        removeTimeObserver()
        
        if let player = player {
            player.pause()
            player.replaceCurrentItem(with: nil)
        }
        
        isPlaying = false
        currentJam = nil
        currentTrack = track
        currentTime = 0
        duration = Double(track.duration)
        
        let asset = AVURLAsset(url: url, options: [AVURLAssetPreferPreciseDurationAndTimingKey: false])
        let playerItem = AVPlayerItem(asset: asset)
        playerItem.preferredForwardBufferDuration = 1.0
        
        let newPlayer = AVPlayer(playerItem: playerItem)
        newPlayer.volume = 1.0
        newPlayer.automaticallyWaitsToMinimizeStalling = false
        
        self.player = newPlayer
        
        setupTimeObserver()
        
        DispatchQueue.main.async {
            newPlayer.playImmediately(atRate: 1.0)
            self.isPlaying = true
        }
    }
    
    func play(track: AudiusTrack) {
        stopSpatialAudioIfNeeded()
        
        let url = track.streamURL
        
        removeTimeObserver()
        
        if let player = player {
            player.pause()
            player.replaceCurrentItem(with: nil)
            self.player = nil
        }
        
        isPlaying = false
        currentJam = nil
        currentTime = 0
        duration = Double(track.duration)
        
        let playerItem = AVPlayerItem(url: url)
        let newPlayer = AVPlayer(playerItem: playerItem)
        newPlayer.volume = 1.0
        
        self.player = newPlayer
        
        setupTimeObserver()
        
        DispatchQueue.main.async {
            newPlayer.play()
            self.isPlaying = true
            self.currentTrack = track
        }
    }
    
    func pause() {
        player?.pause()
        isPlaying = false
    }
    
    func resume() {
        player?.play()
        isPlaying = true
    }
    
    func togglePlayPause(for track: AudiusTrack) {
        if currentTrack?.id == track.id {
            if isPlaying {
                pause()
            } else {
                resume()
            }
        } else {
            playAutomatically(track: track)
        }
    }
    
    func stop() {
        removeTimeObserver()
        player?.pause()
        player = nil
        currentTrack = nil
        currentJam = nil
        isPlaying = false
        currentTime = 0
        duration = 0
    }
    
    func seek(to time: Double) {
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        player?.seek(to: cmTime) { [weak self] completed in
            if completed {
                DispatchQueue.main.async {
                    self?.currentTime = time
                }
            }
        }
    }
    
    private func setupTimeObserver() {
        guard let player = player else { return }
        
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self else { return }
            
            let seconds = time.seconds
            if seconds.isFinite {
                self.currentTime = seconds
            }
            
            if let itemDuration = self.player?.currentItem?.duration.seconds,
               itemDuration.isFinite && itemDuration > 0 {
                self.duration = itemDuration
            }
        }
    }
    
    private func removeTimeObserver() {
        if let observer = timeObserver, let player = player {
            player.removeTimeObserver(observer)
        }
        timeObserver = nil
    }
    
    deinit {
        removeTimeObserver()
        NotificationCenter.default.removeObserver(self)
    }
}



