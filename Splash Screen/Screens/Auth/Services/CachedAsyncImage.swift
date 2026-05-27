//
//  CachedAsyncImage.swift
//  Splash Screen
//
//  Created by Alexis Horteales Espinosa on 15/01/26.
//

import SwiftUI

/// AsyncImage con cache - carga instantánea si ya está cacheada
struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    let content: (Image) -> Content
    let placeholder: () -> Placeholder
    
    @State private var cachedImage: UIImage?
    @State private var isLoading = false
    
    init(
        url: URL?,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
    }
    
    var body: some View {
        Group {
            if let image = cachedImage {
                content(Image(uiImage: image))
            } else if isLoading {
                placeholder()
            } else {
                placeholder()
                    .onAppear {
                        loadImage()
                    }
            }
        }
    }
    
    private func loadImage() {
        guard let url = url else { return }
        let urlString = url.absoluteString
        
        // 1. Verificar cache primero (instantáneo)
        if let cached = ImageCacheService.shared.getImage(for: urlString) {
            cachedImage = cached
            return
        }
        
        // 2. Si no está en cache, descargar
        isLoading = true
        
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let image = UIImage(data: data) {
                    // Guardar en cache
                    ImageCacheService.shared.cacheImage(image, for: urlString)
                    
                    await MainActor.run {
                        self.cachedImage = image
                        self.isLoading = false
                    }
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
}

// MARK: - Convenience init sin placeholder personalizado

extension CachedAsyncImage where Placeholder == ProgressView<EmptyView, EmptyView> {
    init(
        url: URL?,
        @ViewBuilder content: @escaping (Image) -> Content
    ) {
        self.init(url: url, content: content) {
            ProgressView()
        }
    }
}
