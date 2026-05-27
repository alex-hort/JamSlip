//
//  SpatialAudioPlayerManager.swift
//  Splash Screen
//
//  Created by Alexis Horteales Espinosa on 04/02/26.
//
import SwiftUI
import RealityKit
import Combine
import AVFoundation
import MediaPlayer

/// ViewModel para reproducción con Spatial Audio real usando RealityKit
/// Con queue de reproducción, precarga en background, y soporte para pantalla bloqueada
@MainActor
final class SpatialAudioViewModel: ObservableObject {
    
    // MARK: - Singleton
    static let shared = SpatialAudioViewModel()
    
    // MARK: - Published Audio Levels (dB: -60 to 0)
    @Published var reverbLevel: Audio.Decibel = -10.0
    @Published var directLevel: Audio.Decibel = -2.0
    @Published var gain: Audio.Decibel = 2.0
    
    // MARK: - Playback State
    @Published var isPlaying = false
    @Published var isLoading = false
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var errorMessage: String?
    
    // MARK: - Queue
    @Published var queue: [QueueItem] = []
    @Published var currentIndex: Int = 0
    
    // Current content (computed from queue)
    var currentTrack: AudiusTrack? {
        guard queue.indices.contains(currentIndex) else { return nil }
        if case .track(let track) = queue[currentIndex].content {
            return track
        }
        return nil
    }
    
    var currentJam: Jam? {
        guard queue.indices.contains(currentIndex) else { return nil }
        if case .jam(let jam) = queue[currentIndex].content {
            return jam
        }
        return nil
    }
    
    var currentPlayingId: String? {
        currentTrack?.id ?? currentJam?.id
    }
    
    var hasNext: Bool {
        currentIndex < queue.count - 1
    }
    
    var hasPrevious: Bool {
        currentIndex > 0
    }
    
    // MARK: - RealityKit Components
    let reverbEntity = Entity()
    private var audioEntity: Entity?
    private var audioController: AudioPlaybackController?
    
    // MARK: - Preloaded Audio Cache
    private var preloadedFiles: [String: URL] = [:] // id -> local file URL
    private var preloadTasks: [String: Task<URL?, Error>] = [:]
    private let maxPreloadedFiles = 5
    
    // MARK: - AVPlayer for streaming (fallback while downloading)
    private var avPlayer: AVPlayer?
    private var avTimeObserver: Any?
    private var useAVPlayer = false
    
    // MARK: - Time Tracking
    private var playbackStartTime: Date?
    private var accumulatedTime: Double = 0
    private var timeUpdateTimer: Timer?
    
    // MARK: - Init
    private init() {
        setupReverbEnvironment()
        setupAudioSession()
        setupRemoteCommands()
    }
    
    private func setupReverbEnvironment() {
        let reverb = Reverb.preset(.concertHall)
        let component = ReverbComponent(reverb: reverb)
        reverbEntity.components.set(component)
    }
    
    // MARK: - Audio Session for Background
    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.allowAirPlay, .allowBluetooth])
            try session.setActive(true)
        } catch {
            print("❌ AudioSession error: \(error)")
        }
    }
    
    // MARK: - Remote Commands (Lock Screen Controls)
    private func setupRemoteCommands() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.resume()
            }
            return .success
        }
        
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.pause()
            }
            return .success
        }
        
        commandCenter.nextTrackCommand.isEnabled = true
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                await self?.playNext()
            }
            return .success
        }
        
        commandCenter.previousTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                await self?.playPrevious()
            }
            return .success
        }
        
        commandCenter.changePlaybackPositionCommand.isEnabled = true
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            Task { @MainActor in
                self?.seek(to: event.positionTime)
            }
            return .success
        }
    }
    
    private func updateNowPlayingInfo() {
        var info = [String: Any]()
        
        info[MPMediaItemPropertyTitle] = currentTrack?.title ?? currentJam?.title ?? "Unknown"
        info[MPMediaItemPropertyArtist] = currentTrack?.user.name ?? currentJam?.username ?? ""
        info[MPMediaItemPropertyPlaybackDuration] = duration
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        
        // Load artwork
        if let urlString = currentTrack?.imageURL ?? currentJam?.artworkUrl,
           let url = URL(string: urlString) {
            Task.detached {
                if let data = try? Data(contentsOf: url),
                   let image = UIImage(data: data) {
                    await MainActor.run {
                        var updatedInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
                        updatedInfo[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
                        MPNowPlayingInfoCenter.default().nowPlayingInfo = updatedInfo
                    }
                }
            }
        }
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
    
    // MARK: - Set Queue
    func setQueue(tracks: [AudiusTrack] = [], jams: [Jam] = [], startIndex: Int = 0) {
        var items: [QueueItem] = []
        
        for track in tracks {
            items.append(QueueItem(content: .track(track)))
        }
        
        for jam in jams {
            items.append(QueueItem(content: .jam(jam)))
        }
        
        self.queue = items
        self.currentIndex = min(startIndex, items.count - 1)
        
        // Precargar el item actual Y los próximos inmediatamente
        preloadCurrentAndUpcoming()
    }
    
    func setQueue(jams: [Jam], startIndex: Int = 0) {
        setQueue(tracks: [], jams: jams, startIndex: startIndex)
    }
    
    func setQueue(tracks: [AudiusTrack], startIndex: Int = 0) {
        setQueue(tracks: tracks, jams: [], startIndex: startIndex)
    }
    
    // MARK: - Preload Current + Upcoming (called when queue is set)
    private func preloadCurrentAndUpcoming() {
        let start = currentIndex
        let end = min(currentIndex + 6, queue.count)
        
        guard start < end else { return }
        
        for i in start..<end {
            let item = queue[i]
            let id: String
            let url: URL?
            
            switch item.content {
            case .track(let track):
                id = track.id
                url = track.streamURL
            case .jam(let jam):
                id = jam.id
                url = URL(string: jam.audioUrl)
            }
            
            guard preloadedFiles[id] == nil, preloadTasks[id] == nil, let downloadURL = url else { continue }
            
            // Current item = userInitiated (highest), next = high, rest = medium
            let priority: TaskPriority = (i == start) ? .userInitiated : (i == start + 1) ? .high : .medium
            
            Task.detached(priority: priority) {
                _ = await self.downloadAudioFast(id: id, from: downloadURL)
                print("✅ Precargado[\(i)]: \(id)")
            }
        }
    }
    
    // MARK: - Play Current
    func playCurrent() async {
        guard queue.indices.contains(currentIndex) else { return }
        
        let item = queue[currentIndex]
        
        switch item.content {
        case .track(let track):
            await playItem(track: track)
        case .jam(let jam):
            await playItem(jam: jam)
        }
    }
    
    // MARK: - Play Track
    func play(track: AudiusTrack) async {
        // Buscar en queue o agregar
        if let index = queue.firstIndex(where: {
            if case .track(let t) = $0.content { return t.id == track.id }
            return false
        }) {
            currentIndex = index
        } else {
            // No está en queue, crear nueva queue solo con este track
            setQueue(tracks: [track], startIndex: 0)
        }
        
        await playCurrent()
    }
    
    // MARK: - Play Jam
    func playJam(_ jam: Jam) async {
        // Buscar en queue o agregar
        if let index = queue.firstIndex(where: {
            if case .jam(let j) = $0.content { return j.id == jam.id }
            return false
        }) {
            currentIndex = index
        } else {
            setQueue(jams: [jam], startIndex: 0)
        }
        
        await playCurrent()
    }
    
    // MARK: - Play Item Internal
    private func playItem(track: AudiusTrack) async {
        await stopCurrentPlayback()
        
        duration = Double(track.duration)
        isLoading = true
        
        // Detener reproductor normal
        AudioPlayerManager.shared.stop()
        
        // Verificar si ya está precargado
        if let localURL = preloadedFiles[track.id] {
            // Ya descargado - reproducir inmediatamente con spatial audio
            await playLocalFile(localURL)
        } else {
            // Descargar primero (rápido) y luego reproducir con spatial
            if let localURL = await downloadAudioFast(id: track.id, from: track.streamURL) {
                await playLocalFile(localURL)
            } else {
                // Fallback: reproducir sin spatial si falla descarga
                playWithAVPlayer(url: track.streamURL)
            }
        }
        
        updateNowPlayingInfo()
        preloadUpcoming()
    }
    
    private func playItem(jam: Jam) async {
        await stopCurrentPlayback()
        
        guard let url = URL(string: jam.audioUrl) else {
            errorMessage = "Invalid audio URL"
            return
        }
        
        duration = Double(jam.duration)
        isLoading = true
        
        // Detener reproductor normal
        AudioPlayerManager.shared.stop()
        
        // Verificar si ya está precargado
        if let localURL = preloadedFiles[jam.id] {
            // Ya descargado - reproducir inmediatamente con spatial audio
            await playLocalFile(localURL)
        } else {
            // Descargar primero (rápido) y luego reproducir con spatial
            if let localURL = await downloadAudioFast(id: jam.id, from: url) {
                await playLocalFile(localURL)
            } else {
                // Fallback: reproducir sin spatial si falla descarga
                playWithAVPlayer(url: url)
            }
        }
        
        updateNowPlayingInfo()
        preloadUpcoming()
    }
    
    // MARK: - Fast Download (optimized for quick start)
    private func downloadAudioFast(id: String, from url: URL) async -> URL? {
        // Check cache first
        if let cached = preloadedFiles[id] {
            return cached
        }
        
        // Check if already downloading - wait for it
        if let existingTask = preloadTasks[id] {
            return try? await existingTask.value
        }
        
        let task = Task<URL?, Error> {
            // Use optimized session for fastest possible download
            let config = URLSessionConfiguration.default
            config.networkServiceType = .responsiveAV // Highest priority for AV content
            config.timeoutIntervalForRequest = 15
            config.timeoutIntervalForResource = 60
            config.httpMaximumConnectionsPerHost = 8
            config.httpShouldUsePipelining = true
            config.requestCachePolicy = .returnCacheDataElseLoad
            
            let session = URLSession(configuration: config)
            
            let (tempURL, response) = try await session.download(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                throw URLError(.badServerResponse)
            }
            
            let destURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("\(id).mp3")
            
            // Remove if exists
            try? FileManager.default.removeItem(at: destURL)
            try FileManager.default.moveItem(at: tempURL, to: destURL)
            
            return destURL
        }
        
        preloadTasks[id] = task
        
        do {
            let result = try await task.value
            preloadTasks.removeValue(forKey: id)
            
            if let fileURL = result {
                preloadedFiles[id] = fileURL
                cleanupOldPreloads()
            }
            
            return result
        } catch {
            preloadTasks.removeValue(forKey: id)
            print("❌ Download failed: \(error)")
            return nil
        }
    }
    
    // MARK: - AVPlayer (Streaming mientras descarga)
    private func playWithAVPlayer(url: URL) {
        useAVPlayer = true
        
        let asset = AVURLAsset(url: url)
        let playerItem = AVPlayerItem(asset: asset)
        playerItem.preferredForwardBufferDuration = 2.0
        
        avPlayer = AVPlayer(playerItem: playerItem)
        avPlayer?.volume = 1.0
        
        setupAVTimeObserver()
        
        avPlayer?.play()
        isPlaying = true
        isLoading = false
    }
    
    private func setupAVTimeObserver() {
        guard let player = avPlayer else { return }
        
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        avTimeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self, self.useAVPlayer else { return }
            
            let seconds = time.seconds
            if seconds.isFinite {
                self.currentTime = seconds
                self.updateNowPlayingInfo()
            }
            
            if let itemDuration = player.currentItem?.duration.seconds,
               itemDuration.isFinite && itemDuration > 0 {
                self.duration = itemDuration
            }
        }
        
        // Observar cuando termine
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: avPlayer?.currentItem,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.playNext()
            }
        }
    }
    
    private func stopAVPlayer() {
        if let observer = avTimeObserver, let player = avPlayer {
            player.removeTimeObserver(observer)
        }
        avTimeObserver = nil
        avPlayer?.pause()
        avPlayer = nil
        useAVPlayer = false
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
    }
    
    // MARK: - Play Local File with RealityKit
    private func playLocalFile(_ fileURL: URL, startAt: Double = 0) async {
        do {
            let configuration = AudioFileResource.Configuration(
                shouldLoop: false,
                shouldRandomizeStartTime: false
            )
            
            let audioResource = try AudioFileResource.load(
                contentsOf: fileURL,
                configuration: configuration
            )
            
            let entity = Entity()
            
            let focus: Double = 0.2
            entity.spatialAudio = SpatialAudioComponent(
                gain: gain,
                directivity: .beam(focus: focus)
            )
            
            entity.spatialAudio?.reverbLevel = reverbLevel
            entity.spatialAudio?.directLevel = directLevel
            
            self.audioEntity = entity
            reverbEntity.addChild(entity)
            
            let controller = entity.playAudio(audioResource)
            self.audioController = controller
            
            isPlaying = true
            isLoading = false
            useAVPlayer = false
            
            // Start time tracking
            accumulatedTime = startAt
            currentTime = startAt
            startTimeTracking()
            
            updateNowPlayingInfo()
            
        } catch {
            print("❌ Failed to load audio: \(error)")
            errorMessage = "Failed to play audio"
            isLoading = false
        }
    }
    

    // MARK: - Preload Upcoming (Aggressive)
    private func preloadUpcoming() {
        let start = currentIndex + 1
        let end = min(currentIndex + 6, queue.count) // Preload 5 upcoming
        
        guard start < end else { return }
        
        for i in start..<end {
            let item = queue[i]
            let id: String
            let url: URL?
            
            switch item.content {
            case .track(let track):
                id = track.id
                url = track.streamURL
            case .jam(let jam):
                id = jam.id
                url = URL(string: jam.audioUrl)
            }
            
            // Skip if already preloaded or downloading
            guard preloadedFiles[id] == nil, preloadTasks[id] == nil, let downloadURL = url else { continue }
            
            // Higher priority for next track
            let priority: TaskPriority = (i == start) ? .high : .medium
            
            Task.detached(priority: priority) {
                _ = await self.downloadAudioFast(id: id, from: downloadURL)
                print("✅ Precargado: \(id)")
            }
        }
    }
    
    private func cleanupOldPreloads() {
        guard preloadedFiles.count > maxPreloadedFiles else { return }
        
        // Keep current and next few, remove old ones
        let keepIds = Set(queue[max(0, currentIndex - 1)..<min(currentIndex + 4, queue.count)].map { item -> String in
            switch item.content {
            case .track(let t): return t.id
            case .jam(let j): return j.id
            }
        })
        
        for (id, url) in preloadedFiles {
            if !keepIds.contains(id) {
                try? FileManager.default.removeItem(at: url)
                preloadedFiles.removeValue(forKey: id)
            }
        }
    }
    
    // MARK: - Navigation
    func playNext() async {
        guard hasNext else { return }
        currentIndex += 1
        await playCurrent()
    }
    
    func playPrevious() async {
        guard hasPrevious else { return }
        currentIndex -= 1
        await playCurrent()
    }
    
    // MARK: - Controls
    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            resume()
        }
    }
    
    func pause() {
        if useAVPlayer {
            avPlayer?.pause()
        } else {
            audioController?.pause()
            if let startTime = playbackStartTime {
                accumulatedTime += Date().timeIntervalSince(startTime)
            }
            playbackStartTime = nil
        }
        isPlaying = false
        stopTimeTracking()
        updateNowPlayingInfo()
    }
    
    func resume() {
        if useAVPlayer {
            avPlayer?.play()
        } else {
            audioController?.play()
            playbackStartTime = Date()
            startTimeTracking()
        }
        isPlaying = true
        updateNowPlayingInfo()
    }
    
    func seek(to time: Double) {
            print("🎯 Seek to: \(Int(time))s")
            
            if useAVPlayer {
                // ✅ AVPlayer soporta seek nativo
                let cmTime = CMTime(seconds: time, preferredTimescale: 600)
                avPlayer?.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] completed in
                    if completed {
                        DispatchQueue.main.async {
                            self?.currentTime = time
                            self?.updateNowPlayingInfo()
                            print("✅ Seek completado (AVPlayer): \(Int(time))s")
                        }
                    }
                }
            } else {
                // ✅ RealityKit NO soporta seek - pero SÍ podemos cambiar el AVAudioPlayer interno
                // La forma más rápida es recargar el audio desde ese punto
                
                guard let currentId = currentPlayingId,
                      let localURL = preloadedFiles[currentId] else {
                    // No hay archivo local, solo actualizar tiempo visual
                    accumulatedTime = time
                    currentTime = time
                    updateNowPlayingInfo()
                    print("⚠️ Seek solo visual (no local file)")
                    return
                }
                
                let wasPlaying = isPlaying
                
                Task {
                    // Detener audio actual
                    audioController?.stop()
                    audioEntity?.removeFromParent()
                    audioEntity = nil
                    audioController = nil
                    stopTimeTracking()
                    
                    // Recargar desde el nuevo tiempo
                    await playLocalFile(localURL, startAt: time)
                    
                    // Si estaba pausado, pausar de nuevo
                    if !wasPlaying {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            self.pause()
                        }
                    }
                    
                    print("✅ Seek completado (RealityKit reload): \(Int(time))s")
                }
            }
        }
    
    private func stopCurrentPlayback() async {
        stopTimeTracking()
        stopAVPlayer()
        
        audioController?.stop()
        audioController = nil
        audioEntity?.removeFromParent()
        audioEntity = nil
        
        currentTime = 0
        accumulatedTime = 0
        playbackStartTime = nil
    }
    
    func stop() async {
        await stopCurrentPlayback()
        
        isPlaying = false
        isLoading = false
        queue = []
        currentIndex = 0
        
        // Cancel all preload tasks
        for task in preloadTasks.values {
            task.cancel()
        }
        preloadTasks.removeAll()
        
        // Cleanup preloaded files
        for url in preloadedFiles.values {
            try? FileManager.default.removeItem(at: url)
        }
        preloadedFiles.removeAll()
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }
    
    func stopIfPlaying() {
        guard isPlaying || !queue.isEmpty else { return }
        Task {
            await stop()
        }
    }
    
    // MARK: - Update Audio Properties
    func updateAudioProperties() {
        guard let audioEntity = audioEntity,
              var spatialAudio = audioEntity.components[SpatialAudioComponent.self] else {
            return
        }
        
        spatialAudio.gain = gain
        spatialAudio.reverbLevel = reverbLevel
        spatialAudio.directLevel = directLevel
        audioEntity.components.set(spatialAudio)
    }
    
    // MARK: - Time Tracking
    private func startTimeTracking() {
        playbackStartTime = Date()
        
        timeUpdateTimer?.invalidate()
        timeUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateCurrentTime()
            }
        }
    }
    
    private func stopTimeTracking() {
        timeUpdateTimer?.invalidate()
        timeUpdateTimer = nil
    }
    
    private func updateCurrentTime() {
        guard isPlaying, !useAVPlayer, let startTime = playbackStartTime else { return }
        
        let elapsed = Date().timeIntervalSince(startTime)
        currentTime = accumulatedTime + elapsed
        
        if currentTime >= duration {
            currentTime = duration
            Task {
                await playNext()
            }
        }
    }
}

// MARK: - Queue Item
struct QueueItem: Identifiable {
    let id = UUID()
    let content: QueueContent
    
    enum QueueContent {
        case track(AudiusTrack)
        case jam(Jam)
    }
}

