//
//  ArtistAvatarView.swift
//  Splash Screen
//
//  Created by Alexis Horteales Espinosa on 18/01/26.
//
import SwiftUI

struct ArtistAvatarView: View {
    let profileUrl: String?
    let name: String
    
    @State private var cachedImage: UIImage?
    
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.25),
                            Color.white.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            if let image = cachedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                initialLetter
            }
        }
        .frame(width: 44, height: 44) // 👈 más elegante
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.35), radius: 4, y: 2)
        .onAppear {
            loadImageFast()
        }
    }
    
    private var initialLetter: some View {
        Text(String(name.prefix(1)).uppercased())
            .font(.system(size: 18, weight: .semibold))
            .foregroundColor(.white.opacity(0.9))
    }
    
    private func loadImageFast() {
        guard let urlString = profileUrl, !urlString.isEmpty else { return }
        
        if let cached = ImageCacheService.shared.getImage(for: urlString) {
            self.cachedImage = cached
            return
        }
        
        Task(priority: .high) {
            await ImageCacheService.shared.preloadImage(from: urlString)
            if let image = ImageCacheService.shared.getImage(for: urlString) {
                await MainActor.run {
                    self.cachedImage = image
                }
            }
        }
    }
}
