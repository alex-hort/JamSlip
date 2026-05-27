
//
//  ImageCacheService.swift
//  Splash Screen
//
//  Created by Alexis Horteales Espinosa on 15/01/26.
//

import SwiftUI
import Foundation

/// Servicio de cache de imágenes en memoria y disco
class ImageCacheService {
    static let shared = ImageCacheService()
    
    // Cache en memoria (rápido)
    private let memoryCache = NSCache<NSString, UIImage>()
    
    // Cache en disco
    private let fileManager = FileManager.default
    private var cacheDirectory: URL? {
        fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first?.appendingPathComponent("ImageCache")
    }
    
    private init() {
        // Configurar límites de memoria
        memoryCache.countLimit = 100
        memoryCache.totalCostLimit = 50 * 1024 * 1024 // 50MB
        
        // Crear directorio de cache si no existe
        if let cacheDir = cacheDirectory {
            try? fileManager.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        }
    }
    
    // MARK: - Get Image
    func getImage(for url: String) -> UIImage? {
        let key = cacheKey(for: url)
        
        // 1. Buscar en memoria (más rápido)
        if let cachedImage = memoryCache.object(forKey: key as NSString) {
            return cachedImage
        }
        
        // 2. Buscar en disco
        if let diskImage = loadFromDisk(key: key) {
            // Guardar en memoria para próxima vez
            memoryCache.setObject(diskImage, forKey: key as NSString)
            return diskImage
        }
        
        return nil
    }
    
    // MARK: - Cache Image
    func cacheImage(_ image: UIImage, for url: String) {
        let key = cacheKey(for: url)
        
        // Guardar en memoria
        memoryCache.setObject(image, forKey: key as NSString)
        
        // Guardar en disco (async)
        Task.detached(priority: .background) {
            self.saveToDisk(image: image, key: key)
        }
    }
    
    // MARK: - Remove from Cache
    func removeFromCache(url: String) {
        let key = cacheKey(for: url)
        
        // Remover de memoria
        memoryCache.removeObject(forKey: key as NSString)
        
        // Remover de disco
        if let path = diskPath(for: key) {
            try? fileManager.removeItem(at: path)
        }
    }
    
    // MARK: - Preload Image
    func preloadImage(from urlString: String) async {
        // Si ya está en cache, no hacer nada
        if getImage(for: urlString) != nil { return }
        
        guard let url = URL(string: urlString) else { return }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let image = UIImage(data: data) {
                await MainActor.run {
                    self.cacheImage(image, for: urlString)
                }
            }
        } catch {}
    }
    
    // MARK: - Helpers
    
    private func cacheKey(for url: String) -> String {
        url.data(using: .utf8)?.base64EncodedString() ?? url.replacingOccurrences(of: "/", with: "_")
    }
    
    private func diskPath(for key: String) -> URL? {
        cacheDirectory?.appendingPathComponent(key + ".jpg")
    }
    
    private func loadFromDisk(key: String) -> UIImage? {
        guard let path = diskPath(for: key),
              let data = try? Data(contentsOf: path),
              let image = UIImage(data: data) else {
            return nil
        }
        return image
    }
    
    private func saveToDisk(image: UIImage, key: String) {
        guard let path = diskPath(for: key),
              let data = image.jpegData(compressionQuality: 0.8) else {
            return
        }
        try? data.write(to: path)
    }
    
    // MARK: - Clear Cache
    func clearMemoryCache() {
        memoryCache.removeAllObjects()
    }
    
    func clearDiskCache() {
        guard let cacheDir = cacheDirectory else { return }
        try? fileManager.removeItem(at: cacheDir)
        try? fileManager.createDirectory(at: cacheDir, withIntermediateDirectories: true)
    }
}
