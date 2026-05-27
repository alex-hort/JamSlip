//
//  UploadJamsView.swift
//  Splash Screen
//
//  Created by Alexis Horteales Espinosa on 21/01/26.
//

import SwiftUI
import PhotosUI

struct UploadJamsView: View {
    
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = JamUploadViewModel()
    
    @State private var selectedPhotoItem: PhotosPickerItem?
    
    let accentPurple = Color(red: 0.72, green: 0.45, blue: 0.95)
    
    var body: some View {
        NavigationStack {
            ZStack {
                ScrollView {
                    VStack(spacing: 28) {
                        
                        // MARK: Upload Track
                        audioUploadSection
                        
                        Divider().background(Color.white.opacity(0.2))
                        
                        // MARK: Album Cover
                        artworkSection
                        
                        Divider().background(Color.white.opacity(0.2))
                        
                        // MARK: Title
                        titleSection
                        
                        Divider().background(Color.white.opacity(0.2))
                        
                        // MARK: Genre
                        genreSection
                        
                        Divider().background(Color.white.opacity(0.2))
                        
                        // MARK: Moods
                        moodsSection
                        
                        Divider().background(Color.white.opacity(0.2))
                        
                        // MARK: Description
                        descriptionSection
                        
                        // MARK: Pro Message
                        Text("With Slip Pro, your track is matched with the right listeners automatically.")
                            .font(.footnote)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(16)
                        
                        // MARK: Legal
                        Text("By uploading, you confirm that your audio complies with our Terms of Use and does not infringe any rights.")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.6))
                            .multilineTextAlignment(.center)
                        
                        // MARK: Upload Button
                        uploadButton
                    }
                    .padding()
                }
                .background(Color.black.ignoresSafeArea())
                
                if viewModel.isUploading {
                    uploadingOverlay
                }
            }
            .navigationTitle("Upload Jam")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
            .sheet(isPresented: $viewModel.showAudioPicker) {
                AudioDocumentPicker { url in
                    viewModel.handleAudioSelection(url: url)
                }
            }
            .onChange(of: selectedPhotoItem) { _, newValue in
                Task {
                    await viewModel.handleImageSelection(item: newValue)
                }
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage)
            }
            .alert("Upload Limit", isPresented: $viewModel.showUploadLimitError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.uploadLimitMessage)
            }
            .onChange(of: viewModel.uploadSuccess) { _, success in
                if success {
                    dismiss()
                }
            }
        }
    }
    
    // MARK: - Audio Section
    private var audioUploadSection: some View {
        VStack(spacing: 12) {
            Text("Track")
                .font(.headline)
                .foregroundColor(.white)
            
            Button {
                viewModel.showAudioPicker = true
            } label: {
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        viewModel.selectedAudioURL != nil ? accentPurple : Color.white.opacity(0.3),
                        style: StrokeStyle(lineWidth: 1, dash: viewModel.selectedAudioURL != nil ? [] : [6])
                    )
                    .frame(height: 80)
                    .overlay(
                        VStack(spacing: 6) {
                            if let audioName = viewModel.selectedAudioName {
                                Image(systemName: "music.note")
                                    .font(.system(size: 24))
                                    .foregroundColor(accentPurple)
                                
                                Text(audioName)
                                    .font(.footnote)
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                
                                if viewModel.audioDuration > 0 {
                                    HStack(spacing: 4) {
                                        Image(systemName: viewModel.audioDuration <= 420 ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                            .font(.caption2)
                                            .foregroundColor(viewModel.durationStatusColor)
                                        
                                        Text(viewModel.durationStatus)
                                            .font(.caption)
                                            .foregroundColor(viewModel.durationStatusColor)
                                    }
                                }
                            } else {
                                Image(systemName: "arrow.up.circle.fill")
                                    .font(.system(size: 28))
                                    .foregroundColor(.white.opacity(0.8))
                                
                                VStack(spacing: 4) {
                                    Text("Upload your jam (.wav or .mp3)")
                                        .font(.footnote)
                                        .foregroundColor(.white.opacity(0.8))
                                    
                                    Text("Maximum length: 7 minutes")
                                        .font(.caption2)
                                        .foregroundColor(.white.opacity(0.5))
                                }
                            }
                        }
                    )
            }
            
            if viewModel.selectedAudioURL == nil {
                Text("Formats supported: MP3, WAV • Duration: 0:30 – 7:00 min")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.5))
            }
        }
    }
    
    // MARK: - Artwork Section
    private var artworkSection: some View {
        VStack(spacing: 12) {
            Text("Album Artwork")
                .font(.headline)
                .foregroundColor(.white)
            
            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                if let image = viewModel.selectedArtworkImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 220, height: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 28))
                        .overlay(
                            RoundedRectangle(cornerRadius: 28)
                                .stroke(accentPurple, lineWidth: 2)
                        )
                } else {
                    RoundedRectangle(cornerRadius: 28)
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 220, height: 220)
                        .overlay(
                            VStack(spacing: 8) {
                                Image(systemName: "photo")
                                    .font(.system(size: 36))
                                    .foregroundColor(.white.opacity(0.7))
                                
                                Text("1000×1000 px")
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.5))
                            }
                        )
                }
            }
            
            Text("Artwork will be automatically optimized to a 1000×1000 square format.")
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
        }
    }
    
    // MARK: - Title Section
    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Title")
                .font(.headline)
                .foregroundColor(.white)
            
            TextField("Jam title", text: $viewModel.title)
                .padding()
                .background(Color.white.opacity(0.08))
                .cornerRadius(12)
                .foregroundColor(.white)
            
            Text("Clear titles help listeners instantly understand your sound.")
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
        }
    }
    
    // MARK: - Genre Section
    private var genreSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Genre")
                .font(.headline)
                .foregroundColor(.white)
            
            Menu {
                ForEach(Genre.allCases, id: \.self) { genre in
                    Button(genre.rawValue) {
                        viewModel.selectedGenre = genre
                    }
                }
            } label: {
                HStack {
                    Text(viewModel.selectedGenre?.rawValue ?? "Select a genre")
                    Spacer()
                    Image(systemName: "chevron.down")
                }
                .padding()
                .background(Color.white.opacity(0.08))
                .cornerRadius(12)
                .foregroundColor(.white)
            }
            
            Text("Only one genre can be selected.")
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
        }
    }
    
    // MARK: - Moods Section
    private var moodsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Mood")
                .font(.headline)
                .foregroundColor(.white)
            
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 12) {
                ForEach(Mood.allCases, id: \.self) { mood in
                    MoodChip(
                        mood: mood.rawValue.capitalized,
                        color: mood.color,
                        isSelected: viewModel.selectedMoods.contains(mood)
                    ) {
                        viewModel.toggleMood(mood)
                    }
                }
            }
            
            Text("Maximum 5 moods • Selected: \(viewModel.selectedMoods.count)/5")
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
        }
    }
    
    // MARK: - Description Section
    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Description")
                .font(.headline)
                .foregroundColor(.gray)
            
            TextEditor(text: Binding(
                get: { viewModel.description },
                set: { newValue in
                    viewModel.description = limitWords(newValue, limit: 12)
                }
            ))
            .frame(height: 90)
            .padding(10)
            .scrollContentBackground(.hidden)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.gray.opacity(0.15))
            )
            .foregroundColor(accentPurple)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(accentPurple.opacity(0.35), lineWidth: 1)
            )
            
            Text("\(viewModel.description.split(separator: " ").count)/12 words")
                .font(.caption2)
                .foregroundColor(.gray)
        }
    }
    
    // MARK: - Upload Button
    private var uploadButton: some View {
        Button {
            Task {
                await viewModel.uploadJam()
            }
        } label: {
            Text("Upload Jam")
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding()
                .background(viewModel.isFormValid ? Color.white : Color.white.opacity(0.3))
                .foregroundColor(.black)
                .clipShape(RoundedRectangle(cornerRadius: 18))
        }
        .disabled(!viewModel.isFormValid || viewModel.isUploading)
    }
    
    // MARK: - Uploading Overlay
    private var uploadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.8)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(accentPurple)
                
                Text("Uploading your jam...")
                    .font(.headline)
                    .foregroundColor(.white)
                
                ProgressView(value: viewModel.uploadProgress)
                    .progressViewStyle(LinearProgressViewStyle(tint: accentPurple))
                    .frame(width: 200)
                
                Text("\(Int(viewModel.uploadProgress * 100))%")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(40)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white.opacity(0.1))
            )
        }
    }
    
    // MARK: - Helpers
    private func limitWords(_ text: String, limit: Int) -> String {
        let words = text.split(separator: " ")
        if words.count <= limit { return text }
        return words.prefix(limit).joined(separator: " ")
    }
}
