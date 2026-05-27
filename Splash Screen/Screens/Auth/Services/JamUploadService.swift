//
//  JamUploadService.swift
//  Splash Screen
//
//  Created by Alexis Horteales Espinosa on 22/01/26.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import AVFoundation

enum UploadError: LocalizedError {
    case notAuthenticated
    case invalidAudioFile
    case invalidImageFile
    case uploadFailed(String)
    case firestoreFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated: return "Usuario no autenticado"
        case .invalidAudioFile: return "Archivo de audio inválido"
        case .invalidImageFile: return "Imagen inválida"
        case .uploadFailed(let msg): return "Error al subir: \(msg)"
        case .firestoreFailed(let msg): return "Error en base de datos: \(msg)"
        }
    }
}

class JamUploadService {
    static let shared = JamUploadService()
    
    private let storage = Storage.storage()
    private let db = Firestore.firestore()
    
    private init() {}
    
    // MARK: - Subir Jam completo
    func uploadJam(
        audioData: Data,
        audioExtension: String,
        artworkData: Data?,
        title: String,
        description: String,
        genre: String,
        moods: [String],
        duration: Int,
        progressHandler: @escaping (Double) -> Void
    ) async throws -> Jam {
        
        guard let user = Auth.auth().currentUser else {
            throw UploadError.notAuthenticated
        }
        
        // Obtener datos del usuario
        let userDoc = try await db.collection("users").document(user.uid).getDocument()
        let username = userDoc.data()?["username"] as? String ?? "Unknown"
        let userProfileImageUrl = userDoc.data()?["profileImageUrl"] as? String
        
        // ✅ NUEVO: Verificar si el usuario es premium
        let userData = userDoc.data()
        let isPremium = userData?["isPremium"] as? Bool ?? false
        var isValidPremium = false
        
        if isPremium {
            if let expiresAt = userData?["premiumExpiresAt"] as? Timestamp {
                isValidPremium = expiresAt.dateValue() > Date()
            }
        }
        
        let jamId = UUID().uuidString
        let timestamp = Int(Date().timeIntervalSince1970)
        
        // 1. Subir audio (progreso 0-70%)
        let audioPath = "jams/\(user.uid)/\(jamId)/audio_\(timestamp).\(audioExtension)"
        let audioUrl = try await uploadFile(
            data: audioData,
            path: audioPath,
            contentType: audioExtension == "mp3" ? "audio/mpeg" : "audio/wav"
        ) { progress in
            progressHandler(progress * 0.7)
        }
        
        // 2. Subir artwork si existe (progreso 70-90%)
        var artworkUrl: String? = nil
        if let imageData = artworkData {
            let imagePath = "jams/\(user.uid)/\(jamId)/artwork_\(timestamp).jpg"
            artworkUrl = try await uploadFile(
                data: imageData,
                path: imagePath,
                contentType: "image/jpeg"
            ) { progress in
                progressHandler(0.7 + (progress * 0.2))
            }
        }
        
        // 3. Crear documento en Firestore (progreso 90-100%)
        progressHandler(0.9)
        
        let jam = Jam(
            id: jamId,
            userId: user.uid,
            username: username,
            userProfileImageUrl: userProfileImageUrl,
            title: title,
            description: description,
            genre: genre,
            moods: moods,
            audioUrl: audioUrl,
            artworkUrl: artworkUrl,
            duration: duration,
            createdAt: Date(),
            likesCount: 0,
            repostsCount: 0,
            savesCount: 0,
            playsCount: 0,
            hasSpatialAudio: isValidPremium ? true : nil // ✅ Solo si es premium
        )

        // Guardar en Firestore
        try await saveJamToFirestore(jam)
        
        // Actualizar contador de jams del usuario
        try await db.collection("users").document(user.uid).updateData([
            "jamsCount": FieldValue.increment(Int64(1))
        ])
        
        progressHandler(1.0)
        
        print("✅ Jam subido: \(title)")
        print("   Spatial Audio: \(jam.hasSpatialAudio == true ? "✅ SÍ" : "❌ NO")")
        
        return jam
    }
    
    // MARK: - Subir archivo a Storage
    private func uploadFile(
        data: Data,
        path: String,
        contentType: String,
        progressHandler: @escaping (Double) -> Void
    ) async throws -> String {
        
        let storageRef = storage.reference().child(path)
        let metadata = StorageMetadata()
        metadata.contentType = contentType
        
        return try await withCheckedThrowingContinuation { continuation in
            let uploadTask = storageRef.putData(data, metadata: metadata)
            
            uploadTask.observe(.progress) { snapshot in
                if let progress = snapshot.progress {
                    let percent = Double(progress.completedUnitCount) / Double(progress.totalUnitCount)
                    DispatchQueue.main.async {
                        progressHandler(percent)
                    }
                }
            }
            
            uploadTask.observe(.success) { _ in
                storageRef.downloadURL { url, error in
                    if let url = url {
                        continuation.resume(returning: url.absoluteString)
                    } else {
                        continuation.resume(throwing: UploadError.uploadFailed(error?.localizedDescription ?? "Unknown"))
                    }
                }
            }
            
            uploadTask.observe(.failure) { snapshot in
                continuation.resume(throwing: UploadError.uploadFailed(snapshot.error?.localizedDescription ?? "Unknown"))
            }
        }
    }
    
    // MARK: - Guardar en Firestore
    private func saveJamToFirestore(_ jam: Jam) async throws {
        // 🔥 IMPORTANTE: embeddingText será procesado por la extensión Vector Search de Firebase
        let embeddingText = "\(jam.genre) \(jam.moods.joined(separator: " ")) \(jam.title) \(jam.description)".lowercased()
        
        var data: [String: Any] = [
            "id": jam.id,
            "userId": jam.userId,
            "username": jam.username,
            "userProfileImageUrl": jam.userProfileImageUrl as Any,
            "title": jam.title,
            "description": jam.description,
            "genre": jam.genre,
            "moods": jam.moods,
            "audioUrl": jam.audioUrl,
            "artworkUrl": jam.artworkUrl as Any,
            "duration": jam.duration,
            "createdAt": Timestamp(date: jam.createdAt),
            "likesCount": jam.likesCount,
            "repostsCount": jam.repostsCount,
            "savesCount": jam.savesCount,
            "playsCount": jam.playsCount,
            "embeddingText": embeddingText
        ]
        
        // ✅ Solo incluir hasSpatialAudio si es true
        if let hasSpatialAudio = jam.hasSpatialAudio, hasSpatialAudio {
            data["hasSpatialAudio"] = true
        }
        
        // Guardar en colección global (jamsPremium)
        try await db.collection("jamsPremium").document(jam.id).setData(data)
        
        // Guardar en jams del usuario
        try await db.collection("users").document(jam.userId).collection("myJams").document(jam.id).setData(data)
    }
    
    // MARK: - Obtener duración del audio
    static func getAudioDuration(from url: URL) async -> Int {
        let asset = AVURLAsset(url: url)
        do {
            let duration = try await asset.load(.duration)
            return Int(CMTimeGetSeconds(duration))
        } catch {
            return 0
        }
    }
}
