//
//  JamUploadViewModel.swift
//  Splash Screen
//
//  Created by Alexis Horteales Espinosa on 22/01/26.
//
import SwiftUI
import PhotosUI
import AVFoundation
import UniformTypeIdentifiers
import Combine

@MainActor
class JamUploadViewModel: ObservableObject {
    
    // Selection States
    @Published var selectedAudioURL: URL?
    @Published var selectedAudioName: String?
    @Published var selectedArtworkData: Data?
    @Published var selectedArtworkImage: UIImage?
    
    // Form Fields
    @Published var title: String = ""
    @Published var description: String = ""
    @Published var selectedGenre: Genre?
    @Published var selectedMoods: Set<Mood> = []
    
    // UI States
    @Published var isUploading = false
    @Published var uploadProgress: Double = 0
    @Published var showError = false
    @Published var errorMessage = ""
    @Published var uploadSuccess = false
    
    @Published var showAudioPicker = false
    
    // Upload limit states
    @Published var showUploadLimitError = false
    @Published var uploadLimitMessage = ""
    
    // Audio duration
    @Published var audioDuration: Int = 0
    
    // ✅ NEW: Maximum duration limit (7 minutes = 420 seconds)
    private let maxDurationSeconds = 420
    
    // MARK: - Validation
    var isFormValid: Bool {
        selectedAudioURL != nil &&
        !title.trimmingCharacters(in: .whitespaces).isEmpty &&
        selectedGenre != nil &&
        !selectedMoods.isEmpty &&
        audioDuration > 0 &&
        audioDuration <= maxDurationSeconds
    }
    
    // ✅ NEW: Duration Status Message
    var durationStatus: String {
        if audioDuration == 0 {
            return "Waiting for audio..."
        } else if audioDuration > maxDurationSeconds {
            return "⚠️ Maximum duration is 7 minutes"
        } else {
            let minutes = audioDuration / 60
            let seconds = audioDuration % 60
            return String(format: "✓ %d:%02d (valid)", minutes, seconds)
        }
    }
    
    var durationStatusColor: Color {
        if audioDuration == 0 {
            return .gray
        } else if audioDuration > maxDurationSeconds {
            return .red
        } else {
            return .green
        }
    }
    
    // MARK: - Check Upload Limit
    func checkUploadLimit() async -> Bool {
        let result = await MyJamsService.shared.canUploadJam()
        
        if !result.canUpload {
            uploadLimitMessage = result.reason ?? "Upload limit reached."
            showUploadLimitError = true
            return false
        }
        
        return true
    }
    
    // MARK: - Select Audio
    func handleAudioSelection(url: URL) {
        guard url.startAccessingSecurityScopedResource() else {
            showError(message: "Unable to access the selected file.")
            return
        }
        
        defer { url.stopAccessingSecurityScopedResource() }
        
        let tempDir = FileManager.default.temporaryDirectory
        let tempURL = tempDir.appendingPathComponent(url.lastPathComponent)
        
        do {
            if FileManager.default.fileExists(atPath: tempURL.path) {
                try FileManager.default.removeItem(at: tempURL)
            }
            
            try FileManager.default.copyItem(at: url, to: tempURL)
            
            self.selectedAudioURL = tempURL
            self.selectedAudioName = url.lastPathComponent
            
            Task {
                self.audioDuration = await JamUploadService.getAudioDuration(from: tempURL)
                
                if self.audioDuration > maxDurationSeconds {
                    showError(
                        message: "Audio duration exceeds the 7-minute limit. Current duration: \(formatDuration(self.audioDuration))"
                    )
                }
            }
            
        } catch {
            showError(message: "Failed to process the selected file: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Select Image (Auto Optimization)
    func handleImageSelection(item: PhotosPickerItem?) async {
        guard let item = item else { return }
        
        do {
            if let data = try await item.loadTransferable(type: Data.self) {
                if let originalImage = UIImage(data: data) {
                    
                    let optimizedImage = optimizeArtwork(originalImage)
                    
                    if let compressedData = optimizedImage.jpegData(compressionQuality: 0.85) {
                        
                        let sizeInMB = Double(compressedData.count) / 1_048_576
                        
                        if sizeInMB > 2.0 {
                            if let finalData = optimizedImage.jpegData(compressionQuality: 0.7) {
                                self.selectedArtworkData = finalData
                                self.selectedArtworkImage = optimizedImage
                                print("✅ Artwork optimized: \(String(format: "%.2f", Double(finalData.count) / 1_048_576)) MB")
                            }
                        } else {
                            self.selectedArtworkData = compressedData
                            self.selectedArtworkImage = optimizedImage
                            print("✅ Artwork optimized: \(String(format: "%.2f", sizeInMB)) MB")
                        }
                    }
                }
            }
        } catch {
            showError(message: "Failed to load image.")
        }
    }
    
    // MARK: - Optimize Artwork
    private func optimizeArtwork(_ image: UIImage) -> UIImage {
        let targetSize: CGFloat = 1000
        
        let size = image.size
        let aspectRatio = size.width / size.height
        
        var drawRect = CGRect.zero
        
        if aspectRatio > 1 {
            drawRect.size.width = targetSize
            drawRect.size.height = targetSize / aspectRatio
            drawRect.origin.x = 0
            drawRect.origin.y = (targetSize - drawRect.size.height) / 2
        } else {
            drawRect.size.height = targetSize
            drawRect.size.width = targetSize * aspectRatio
            drawRect.origin.x = (targetSize - drawRect.size.width) / 2
            drawRect.origin.y = 0
        }
        
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: targetSize, height: targetSize))
        let finalImage = renderer.image { context in
            UIColor.black.setFill()
            context.fill(CGRect(origin: .zero, size: CGSize(width: targetSize, height: targetSize)))
            image.draw(in: drawRect)
        }
        
        return finalImage
    }
    
    // MARK: - Toggle Mood
    func toggleMood(_ mood: Mood) {
        if selectedMoods.contains(mood) {
            selectedMoods.remove(mood)
        } else if selectedMoods.count < 5 {
            selectedMoods.insert(mood)
        }
    }
    
    // MARK: - Upload Jam
    func uploadJam() async {
        guard isFormValid else {
            if audioDuration > maxDurationSeconds {
                showError(message: "Audio duration cannot exceed 7 minutes.")
            } else {
                showError(message: "Please complete all required fields.")
            }
            return
        }
        
        guard let audioURL = selectedAudioURL else {
            showError(message: "Please select an audio file.")
            return
        }
        
        if audioDuration > maxDurationSeconds {
            showError(
                message: "Audio exceeds the allowed duration. Length: \(formatDuration(audioDuration))"
            )
            return
        }
        
        let canUpload = await checkUploadLimit()
        guard canUpload else { return }
        
        isUploading = true
        uploadProgress = 0
        
        do {
            let audioData = try Data(contentsOf: audioURL)
            
            let audioSizeInMB = Double(audioData.count) / 1_048_576
            if audioSizeInMB > 50 {
                throw UploadError.invalidAudioFile
            }
            
            let audioExtension = audioURL.pathExtension.lowercased()
            
            let _ = try await JamUploadService.shared.uploadJam(
                audioData: audioData,
                audioExtension: audioExtension,
                artworkData: selectedArtworkData,
                title: title.trimmingCharacters(in: .whitespaces),
                description: description.trimmingCharacters(in: .whitespaces),
                genre: selectedGenre?.rawValue ?? "",
                moods: selectedMoods.map { $0.rawValue },
                duration: audioDuration
            ) { [weak self] progress in
                DispatchQueue.main.async {
                    self?.uploadProgress = progress
                }
            }
            
            await MyJamsService.shared.fetchMyJams()
            uploadSuccess = true
            
        } catch {
            showError(message: error.localizedDescription)
        }
        
        isUploading = false
    }
    
    // MARK: - Reset
    func reset() {
        selectedAudioURL = nil
        selectedAudioName = nil
        selectedArtworkData = nil
        selectedArtworkImage = nil
        title = ""
        description = ""
        selectedGenre = nil
        selectedMoods = []
        audioDuration = 0
        uploadProgress = 0
        uploadSuccess = false
    }
    
    // MARK: - Helpers
    private func showError(message: String) {
        errorMessage = message
        showError = true
    }
    
    func formatDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}

// MARK: - Document Picker
struct AudioDocumentPicker: UIViewControllerRepresentable {
    let onPick: (URL) -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let supportedTypes: [UTType] = [.mp3, .wav, .audio]
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: supportedTypes)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void
        
        init(onPick: @escaping (URL) -> Void) {
            self.onPick = onPick
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            if let url = urls.first {
                onPick(url)
            }
        }
    }
}

