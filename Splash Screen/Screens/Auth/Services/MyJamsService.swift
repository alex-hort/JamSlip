//
//  MyJamsService.swift
//  Splash Screen
//
//  Created by Alexis Horteales Espinosa on 22/01/26.
//
import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import Combine

@MainActor
class MyJamsService: ObservableObject {
    static let shared = MyJamsService()
    
    private let db = Firestore.firestore()
    private var feedListener: ListenerRegistration?
    
    // Backend API
    private let baseURL = "https://jamslip-api-577659266872.us-central1.run.app"
    
    @Published var myJams: [Jam] = []
    @Published var feedJams: [Jam] = []
    @Published var likedJams: [Jam] = []
    @Published var savedJams: [Jam] = []
    @Published var isLoading = false
    
    // Reposts visibles en el feed actual
    @Published var visibleReposts: [VisibleJamRepost] = []
    private let notificationService = NotificationService.shared
    
    // IDs de jams ya vistos en esta sesión (para no repetir)
    private var sessionSeenIds: Set<String> = []
    private var addedRepostIds: Set<String> = []
    
    // Gustos del usuario (local)
    private var favoriteGenres: [String: Int] = [:]
    private var favoriteMoods: [String: Int] = [:]
    private var userTasteLoaded = false
    
    // ✅ NUEVO: Límite de uploads para usuarios free
    private let freeUserUploadLimit = 0 // Free users NO pueden subir jams
    
    private init() {}
    
    private var currentUserId: String? { Auth.auth().currentUser?.uid }
    
    // MARK: - ✅ NUEVO: Verificar si usuario puede subir
    func canUploadJam() async -> (canUpload: Bool, reason: String?) {
        guard let userId = currentUserId else {
            return (false, "Debes iniciar sesión")
        }
        
        // Verificar si es premium
        let storeKit = StoreKitManager.shared
        
        if storeKit.isSubscribed {
            // Usuario premium - uploads ilimitados
            return (true, nil)
        }
        
        // Usuario free - NO puede subir
        return (false, "Suscríbete a Premium para subir jams ilimitados")
    }
    
    // MARK: - ✅ NUEVO: Obtener conteo de uploads del usuario
    func getUploadCount() -> Int {
        return myJams.count
    }
    
    // MARK: - ✅ NUEVO: Mensaje de límite para UI
    func getUploadLimitMessage() -> String {
        let storeKit = StoreKitManager.shared
        
        if storeKit.isSubscribed {
            if storeKit.subscriptionInfo.isInTrialPeriod {
                return "Prueba gratis - Uploads ilimitados por 3 días"
            } else {
                return "Premium - Uploads ilimitados"
            }
        } else {
            return "Usuarios free no pueden subir jams"
        }
    }
    
    // MARK: - 🔴 INICIAR FEED (Backend + Real-time + Reposts)
    func startFeedListener() {
        stopFeedListener()
        sessionSeenIds = []
        addedRepostIds = []
        visibleReposts = []
        
        print("🔴 Iniciando feed de jams...")
        
        // 1. Cargar feed inicial desde el backend
        Task {
            // Cargar mis reposts primero
            await JamRepostService.shared.fetchMyReposts()
            
            await loadFeedFromBackend()
            
            // 2. Cargar reposts de amigos
            await loadFriendReposts()
        }
        
        // 3. Iniciar listener de reposts en tiempo real
        JamRepostService.shared.startListening()
        
        // 4. Escuchar nuevos jams en tiempo real
        feedListener = db.collection("jamsPremium")
            .order(by: "createdAt", descending: true)
            .limit(to: 10)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("❌ Feed listener error: \(error)")
                    return
                }
                
                guard let snapshot = snapshot else { return }
                
                for change in snapshot.documentChanges {
                    if change.type == .added {
                        if let newJam = self.decodeJam(from: change.document.data()) {
                            if !self.feedJams.contains(where: { $0.id == newJam.id }) &&
                               !self.sessionSeenIds.contains(newJam.id) {
                                print("🆕 Nuevo jam detectado: \(newJam.title)")
                                self.feedJams.insert(newJam, at: 0)
                            }
                        }
                    }
                }
            }
    }
    
    // MARK: - 🔄 Cargar Reposts de Amigos
    private func loadFriendReposts() async {
        let reposts = await JamRepostService.shared.fetchInitialReposts()
        
        for repost in reposts {
            // No insertar si ya está en el feed
            guard !sessionSeenIds.contains(repost.jamId) else { continue }
            guard !addedRepostIds.contains(repost.id) else { continue }
            
            // Convertir a Jam y agregar al feed con prioridad
            let jam = repost.toJam()
            
            // Insertar al inicio (prioridad temporal)
            feedJams.insert(jam, at: min(2, feedJams.count))
            sessionSeenIds.insert(repost.jamId)
            addedRepostIds.insert(repost.id)
            
            // ✅ Guardar info del repost para notificaciones de like
            repostInfoMap[repost.jamId] = repost
            
            // Agregar a reposts visibles para UI
            let visible = JamRepostService.shared.toVisibleRepost(repost)
            visibleReposts.append(visible)
        }
        
        print("✅ \(reposts.count) jam reposts integrados al feed")
    }
    
    // MARK: - 📥 Insertar Repost Pendiente
    func insertPendingRepost(after currentIndex: Int) {
        guard let repost = JamRepostService.shared.getNextPendingRepost() else { return }
        guard !sessionSeenIds.contains(repost.jamId) else { return }
        guard !addedRepostIds.contains(repost.id) else { return }
        
        let jam = repost.toJam()
        let insertIndex = min(currentIndex + 2, feedJams.count)
        
        if !feedJams.contains(where: { $0.id == jam.id }) {
            feedJams.insert(jam, at: insertIndex)
            sessionSeenIds.insert(repost.jamId)
            addedRepostIds.insert(repost.id)
            
            // ✅ Guardar info del repost para notificaciones de like
            repostInfoMap[repost.jamId] = repost
            
            let visible = JamRepostService.shared.toVisibleRepost(repost)
            visibleReposts.append(visible)
            
            print("📥 Jam repost insertado: \(jam.title)")
        }
    }
    
    // MARK: - 🔍 Obtener Reposts para un Jam
    func getVisibleReposts(for jamId: String) -> [VisibleJamRepost] {
        visibleReposts.filter { $0.jamId == jamId }
    }
    
    // MARK: - 🔍 Obtener RepostInfo para un Jam (para notificaciones)
    func getRepostInfo(for jamId: String) -> JamRepost? {
        return repostInfoMap[jamId]
    }
    
    // Mapa de jamId -> JamRepost (para saber quién reposteó)
    private var repostInfoMap: [String: JamRepost] = [:]
    
//    // MARK: - 🌐 Cargar Feed desde Backend
//    private func loadFeedFromBackend() async {
//        guard let userId = currentUserId else {
//            await loadFeedFromFirebase()
//            return
//        }
//        
//        isLoading = true
//        
//        do {
//            let url = URL(string: "\(baseURL)/api/feed")!
//            var request = URLRequest(url: url)
//            request.httpMethod = "POST"
//            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
//            
//            let body: [String: Any] = [
//                "userId": userId,
//                "excludeIds": Array(sessionSeenIds),
//                "limit": 50
//            ]
//            request.httpBody = try JSONSerialization.data(withJSONObject: body)
//            
//            let (data, response) = try await URLSession.shared.data(for: request)
//            
//            guard let httpResponse = response as? HTTPURLResponse,
//                  httpResponse.statusCode == 200 else {
//                print("⚠️ Backend error, usando Firebase")
//                await loadFeedFromFirebase()
//                return
//            }
//            
//            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
//               let jamsArray = json["jams"] as? [[String: Any]] {
//                
//                let method = json["method"] as? String ?? "unknown"
//                print("✅ Feed desde backend (\(method)): \(jamsArray.count) jams")
//                
//                let jams = jamsArray.compactMap { decodeJam(from: $0) }
//                
//                self.feedJams = jams
//                
//                for jam in jams {
//                    sessionSeenIds.insert(jam.id)
//                }
//            }
//            
//        } catch {
//            print("❌ Error backend: \(error.localizedDescription)")
//            await loadFeedFromFirebase()
//        }
//        
//        isLoading = false
//    }
    
    private func loadFeedFromBackend() async {
        guard let userId = currentUserId else {
            await loadFeedFromFirebase()
            return
        }
        
        // ⚡ 1. Intentar desde caché primero
        let cacheHit = await loadFeedFromCache()
        if cacheHit {
            isLoading = false
            return
        }
        
        isLoading = true
        
        do {
            let url = URL(string: "\(baseURL)/api/feed")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let body: [String: Any] = [
                "userId": userId,
                "excludeIds": Array(sessionSeenIds),
                "limit": 50
            ]
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                print("⚠️ Backend error, usando Firebase")
                await loadFeedFromFirebase()
                return
            }
            
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let jamsArray = json["jams"] as? [[String: Any]] {
                
                let method = json["method"] as? String ?? "unknown"
                print("✅ Feed desde backend (\(method)): \(jamsArray.count) jams")
                
                let jams = jamsArray.compactMap { decodeJam(from: $0) }
                self.feedJams = jams
                for jam in jams { sessionSeenIds.insert(jam.id) }
                
                // ⚡ 2. Guardar en caché para la próxima vez
                await saveFeedToCache(jamsArray: jamsArray)
            }
            
        } catch {
            print("❌ Error backend: \(error.localizedDescription)")
            await loadFeedFromFirebase()
        }
        
        isLoading = false
    }
    
    // MARK: - 🔥 Fallback: Cargar desde Firebase
    private func loadFeedFromFirebase() async {
        print("🔥 Cargando feed desde Firebase...")
        
        do {
            let snapshot = try await db.collection("jamsPremium")
                .order(by: "createdAt", descending: true)
                .limit(to: 100)
                .getDocuments()
            
            var jams = snapshot.documents.compactMap { decodeJam(from: $0.data()) }
            jams = jams.filter { !sessionSeenIds.contains($0.id) }
            jams.shuffle()
            
            self.feedJams = jams
            
            for jam in jams {
                sessionSeenIds.insert(jam.id)
            }
            
            print("✅ Feed desde Firebase: \(jams.count) jams")
            
        } catch {
            print("❌ Error Firebase: \(error)")
        }
        
        isLoading = false
    }
    
    // MARK: - 🔄 Cargar más jams
    func loadMoreJams() async {
        guard let userId = currentUserId else { return }
        guard !isLoading else { return }
        
        isLoading = true
        
        do {
            let url = URL(string: "\(baseURL)/api/feed")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let body: [String: Any] = [
                "userId": userId,
                "excludeIds": Array(sessionSeenIds),
                "limit": 30
            ]
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            
            let (data, _) = try await URLSession.shared.data(for: request)
            
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let jamsArray = json["jams"] as? [[String: Any]] {
                
                let newJams = jamsArray.compactMap { decodeJam(from: $0) }
                
                for jam in newJams {
                    if !feedJams.contains(where: { $0.id == jam.id }) {
                        feedJams.append(jam)
                        sessionSeenIds.insert(jam.id)
                    }
                }
                
                print("➕ Agregados \(newJams.count) jams más")
            }
            
        } catch {
            print("❌ Error cargando más: \(error)")
        }
        
        isLoading = false
    }
    
    func stopFeedListener() {
        feedListener?.remove()
        feedListener = nil
        JamRepostService.shared.stopListening()
    }
    
    // MARK: - Fetch mis jams
    func fetchMyJams() async {
        guard let userId = currentUserId else { return }
        
        isLoading = true
        
        do {
            // Leer desde jamsPremium para obtener los counts actualizados
            let snapshot = try await db.collection("jamsPremium")
                .whereField("userId", isEqualTo: userId)
                .order(by: "createdAt", descending: true)
                .getDocuments()
            
            self.myJams = snapshot.documents.compactMap { decodeJam(from: $0.data()) }
            print("✅ Mis jams: \(myJams.count)")
            
            // Debug: mostrar counts
            for jam in myJams {
                print("   📊 \(jam.title): ❤️\(jam.likesCount) 🔖\(jam.savesCount) 🔄\(jam.repostsCount) ▶️\(jam.playsCount)")
            }
        } catch {
            print("❌ Error fetching my jams: \(error)")
        }
        
        isLoading = false
    }
    
    // MARK: - Fetch jams de otro usuario
    func fetchJams(for userId: String) async -> [Jam] {
        do {
            // Leer desde jamsPremium para obtener counts actualizados
            let snapshot = try await db.collection("jamsPremium")
                .whereField("userId", isEqualTo: userId)
                .order(by: "createdAt", descending: true)
                .getDocuments()
            
            return snapshot.documents.compactMap { decodeJam(from: $0.data()) }
        } catch {
            print("❌ Error fetching jams for user: \(error)")
            return []
        }
    }
    
    // MARK: - Fetch todos los jams (sin listener)
    func fetchAllJams(limit: Int = 50) async -> [Jam] {
        do {
            let snapshot = try await db.collection("jamsPremium")
                .order(by: "createdAt", descending: true)
                .limit(to: limit)
                .getDocuments()
            
            var jams = snapshot.documents.compactMap { decodeJam(from: $0.data()) }
            jams.shuffle()
            self.feedJams = jams
            
            return self.feedJams
        } catch {
            print("❌ Error fetching all jams: \(error)")
            return []
        }
    }
    
//    // MARK: - ❤️ Toggle Like
//    func toggleLike(_ jam: Jam) async throws {
//        guard let userId = currentUserId else { return }
//        
//        // ✅ Obtener usuario actual para notificaciones
//        guard let currentUser = try? await getCurrentUser() else {
//            print("⚠️ No se pudo obtener usuario actual")
//            return
//        }
//        
//        let likeRef = db.collection("users").document(userId).collection("likedJamsPremium").document(jam.id)
//        let jamRef = db.collection("jamsPremium").document(jam.id)
//        
//        let likeDoc = try await likeRef.getDocument()
//        
//        if likeDoc.exists {
//            // UNLIKE
//            try await likeRef.delete()
//            try await jamRef.updateData(["likesCount": FieldValue.increment(Int64(-1))])
//            updateLocalTaste(jam: jam, increment: false)
//            
//            // ✅ ELIMINAR NOTIFICACIÓN DE LIKE
//            await notificationService.deleteLikeNotification(
//                toUserId: jam.userId,
//                trackId: jam.id
//            )
//            
//            print("💔 Like removido")
//            
//        } else {
//            // LIKE
//            try await likeRef.setData([
//                "jamId": jam.id,
//                "likedAt": Timestamp(date: Date())
//            ])
//            try await jamRef.updateData(["likesCount": FieldValue.increment(Int64(1))])
//            updateLocalTaste(jam: jam, increment: true)
//            
//            // Backend para Vector Search
//            await JamSlipAPIService.shared.updateUserTaste(jamId: jam.id)
//            
//            // ✅ ENVIAR NOTIFICACIÓN DE LIKE
//            // Verificar si este jam es un repost
//            if let repostInfo = getRepostInfo(for: jam.id) {
//                // Es un repost - notificar a quien lo reposteó
//                await notificationService.sendJamLikeNotification(
//                    toUserId: repostInfo.userId,  // Quien reposteó
//                    fromUser: currentUser,
//                    jam: jam
//                )
//                print("📬 Notificación de like enviada a \(repostInfo.username) (repost)")
//            } else {
//                // No es repost - notificar al dueño del jam
//                await notificationService.sendJamLikeNotification(
//                    toUserId: jam.userId,  // Dueño del jam
//                    fromUser: currentUser,
//                    jam: jam
//                )
//                print("📬 Notificación de like enviada a \(jam.username)")
//            }
//            
//            print("❤️ Like agregado")
//        }
//        
//        await saveUserTaste()
//    }
    
    func toggleLike(_ jam: Jam) async throws {
        guard let userId = currentUserId else { return }
        guard let currentUser = try? await getCurrentUser() else { return }
        
        let likeRef = db.collection("users").document(userId).collection("likedJamsPremium").document(jam.id)
        let jamRef = db.collection("jamsPremium").document(jam.id)
        let likeDoc = try await likeRef.getDocument()
        
        if likeDoc.exists {
            try await likeRef.delete()
            try await jamRef.updateData(["likesCount": FieldValue.increment(Int64(-1))])
            updateLocalTaste(jam: jam, increment: false)
            await notificationService.deleteLikeNotification(toUserId: jam.userId, trackId: jam.id)
            print("💔 Like removido")
        } else {
            try await likeRef.setData(["jamId": jam.id, "likedAt": Timestamp(date: Date())])
            try await jamRef.updateData(["likesCount": FieldValue.increment(Int64(1))])
            updateLocalTaste(jam: jam, increment: true)
            await JamSlipAPIService.shared.updateUserTaste(jamId: jam.id)
            
            if let repostInfo = getRepostInfo(for: jam.id) {
                await notificationService.sendJamLikeNotification(toUserId: repostInfo.userId, fromUser: currentUser, jam: jam)
            } else {
                await notificationService.sendJamLikeNotification(toUserId: jam.userId, fromUser: currentUser, jam: jam)
            }
            print("❤️ Like agregado")
        }
        
        // ⚡ Gustos cambiaron — invalidar caché
        invalidateFeedCache()
        
        await saveUserTaste()
    }
    
    
    private func getCurrentUser() async throws -> User {
        guard let userId = currentUserId else {
            throw NSError(domain: "MyJamsService", code: 401)
        }
        
        let doc = try await db.collection("users").document(userId).getDocument()
        
        guard let data = doc.data() else {
            throw NSError(domain: "MyJamsService", code: 404)
        }
        
        return User(
            uid: userId,
            email: data["email"] as? String ?? "",
            fullName: data["fullName"] as? String ?? "",
            username: data["username"] as? String ?? "",
            bio: data["bio"] as? String,
            profileImageUrl: data["profileImageUrl"] as? String,
            bannerImageUrl: data["bannerImageUrl"] as? String,
            joinedDate: (data["joinedDate"] as? Timestamp)?.dateValue()
        )
    }
    
    private func updateLocalTaste(jam: Jam, increment: Bool) {
        let delta = increment ? 1 : -1
        
        favoriteGenres[jam.genre, default: 0] += delta
        for mood in jam.moods {
            favoriteMoods[mood, default: 0] += delta
        }
        
        favoriteGenres = favoriteGenres.filter { $0.value > 0 }
        favoriteMoods = favoriteMoods.filter { $0.value > 0 }
        userTasteLoaded = true
    }
    
    private func saveUserTaste() async {
        guard let userId = currentUserId else { return }
        
        do {
            try await db.collection("users").document(userId).setData([
                "favoriteGenres": favoriteGenres,
                "favoriteMoods": favoriteMoods
            ], merge: true)
        } catch {
            print("❌ Error guardando gustos: \(error)")
        }
    }
    
//    // MARK: - 🔖 Toggle Save
//    func toggleSave(_ jam: Jam) async throws {
//        guard let userId = currentUserId else { return }
//        
//        let saveRef = db.collection("users").document(userId).collection("savedJamsPremium").document(jam.id)
//        let jamRef = db.collection("jamsPremium").document(jam.id)
//        
//        let saveDoc = try await saveRef.getDocument()
//        
//        if saveDoc.exists {
//            try await saveRef.delete()
//            try await jamRef.updateData(["savesCount": FieldValue.increment(Int64(-1))])
//            print("🔖 Save removido")
//        } else {
//            try await saveRef.setData([
//                "jamId": jam.id,
//                "savedAt": Timestamp(date: Date())
//            ])
//            try await jamRef.updateData(["savesCount": FieldValue.increment(Int64(1))])
//            
//            // Backend para Vector Search - guardar también cuenta como interés
//            await JamSlipAPIService.shared.updateUserTaste(jamId: jam.id)
//            
//            print("💾 Jam guardado")
//        }
//    }
    func toggleSave(_ jam: Jam) async throws {
        guard let userId = currentUserId else { return }
        
        let saveRef = db.collection("users").document(userId).collection("savedJamsPremium").document(jam.id)
        let jamRef = db.collection("jamsPremium").document(jam.id)
        let saveDoc = try await saveRef.getDocument()
        
        if saveDoc.exists {
            try await saveRef.delete()
            try await jamRef.updateData(["savesCount": FieldValue.increment(Int64(-1))])
            print("🔖 Save removido")
        } else {
            try await saveRef.setData(["jamId": jam.id, "savedAt": Timestamp(date: Date())])
            try await jamRef.updateData(["savesCount": FieldValue.increment(Int64(1))])
            await JamSlipAPIService.shared.updateUserTaste(jamId: jam.id)
            print("💾 Jam guardado")
        }
        
        // ⚡ Gustos cambiaron — invalidar caché
        invalidateFeedCache()
    }
    
    // MARK: - ▶️ Incrementar Play Count (cuando el usuario ve el jam)
    func incrementPlayCount(for jamId: String) {
        // Evitar contar múltiples veces el mismo jam en una sesión
        guard !playedJamIds.contains(jamId) else { return }
        playedJamIds.insert(jamId)
        
        Task {
            do {
                try await db.collection("jamsPremium").document(jamId).updateData([
                    "playsCount": FieldValue.increment(Int64(1))
                ])
                print("▶️ Play contado para jam: \(jamId)")
            } catch {
                print("❌ Error incrementando play: \(error)")
            }
        }
    }
    
    // IDs de jams ya reproducidos en esta sesión (para no contar doble)
    private var playedJamIds: Set<String> = []
    
    // MARK: - Check states
    func isJamLiked(_ jamId: String) async -> Bool {
        guard let userId = currentUserId else { return false }
        do {
            let doc = try await db.collection("users").document(userId).collection("likedJamsPremium").document(jamId).getDocument()
            return doc.exists
        } catch { return false }
    }
    
    func isJamSaved(_ jamId: String) async -> Bool {
        guard let userId = currentUserId else { return false }
        do {
            let doc = try await db.collection("users").document(userId).collection("savedJamsPremium").document(jamId).getDocument()
            return doc.exists
        } catch { return false }
    }
    
    // MARK: - Delete jam
    func deleteJam(_ jam: Jam) async throws {
        guard let userId = currentUserId, jam.userId == userId else { return }
        
        try await db.collection("jamsPremium").document(jam.id).delete()
        try await db.collection("users").document(userId).collection("myJams").document(jam.id).delete()
        try await db.collection("users").document(userId).updateData([
            "jamsCount": FieldValue.increment(Int64(-1))
        ])
        
        myJams.removeAll { $0.id == jam.id }
        feedJams.removeAll { $0.id == jam.id }
    }
    
    // MARK: - Decode Jam
    func decodeJam(from data: [String: Any]) -> Jam? {
        guard let id = data["id"] as? String,
              let odei = data["userId"] as? String,
              let username = data["username"] as? String,
              let title = data["title"] as? String,
              let description = data["description"] as? String,
              let genre = data["genre"] as? String,
              let moods = data["moods"] as? [String],
              let audioUrl = data["audioUrl"] as? String,
              let duration = data["duration"] as? Int else {
            return nil
        }
        
        var createdAt = Date()
        if let timestamp = data["createdAt"] as? Timestamp {
            createdAt = timestamp.dateValue()
        } else if let timestampDict = data["createdAt"] as? [String: Any],
                  let seconds = timestampDict["_seconds"] as? Int {
            createdAt = Date(timeIntervalSince1970: TimeInterval(seconds))
        }
        
        return Jam(
            id: id,
            userId: odei,
            username: username,
            userProfileImageUrl: data["userProfileImageUrl"] as? String,
            title: title,
            description: description,
            genre: genre,
            moods: moods,
            audioUrl: audioUrl,
            artworkUrl: data["artworkUrl"] as? String,
            duration: duration,
            createdAt: createdAt,
            likesCount: data["likesCount"] as? Int ?? 0,
            repostsCount: data["repostsCount"] as? Int ?? 0,
            savesCount: data["savesCount"] as? Int ?? 0,
            playsCount: data["playsCount"] as? Int ?? 0,
            embedding: data["embedding"] as? [Double],
            embeddingText: data["embeddingText"] as? String,
            embeddingStatus: data["embeddingStatus"] as? String
        )
    }
    
    // MARK: - Reset
    func resetOnLogout() {
        stopFeedListener()
        myJams = []
        feedJams = []
        likedJams = []
        savedJams = []
        visibleReposts = []
        repostInfoMap = [:]
        favoriteGenres = [:]
        favoriteMoods = [:]
        userTasteLoaded = false
        sessionSeenIds = []
        addedRepostIds = []
        playedJamIds = []
        JamRepostService.shared.resetOnLogout()
    }
}


// MARK: - Feed Cache Manager
extension MyJamsService {
    
    private var cacheTTL: TimeInterval { 300 } // 5 minutos
    
    /// Intenta cargar el feed desde caché de Firestore.
    /// Retorna `true` si el caché era válido y se cargó, `false` si hay que ir al backend.
    func loadFeedFromCache() async -> Bool {
        guard let userId = currentUserId else { return false }
        
        do {
            let cacheDoc = try await db
                .collection("feedCache")
                .document(userId)
                .getDocument()
            
            guard let data = cacheDoc.data(),
                  let timestamp = data["cachedAt"] as? Timestamp,
                  Date().timeIntervalSince(timestamp.dateValue()) < cacheTTL,
                  let jamsArray = data["jams"] as? [[String: Any]] else {
                print(" Caché expirado o no existe — irá al backend")
                return false
            }
            
            let jams = jamsArray.compactMap { decodeJam(from: $0) }
            guard !jams.isEmpty else { return false }
            
            self.feedJams = jams
            for jam in jams { sessionSeenIds.insert(jam.id) }
            
            print(" Feed desde caché (\(jams.count) jams) — sin query a Vertex AI")
            return true
            
        } catch {
            print(" Error leyendo caché: \(error.localizedDescription)")
            return false
        }
    }
    
    /// Guarda el resultado del feed en Firestore para cachear.
    func saveFeedToCache(jamsArray: [[String: Any]]) async {
        guard let userId = currentUserId else { return }
        
        do {
            try await db.collection("feedCache").document(userId).setData([
                "jams": jamsArray,
                "cachedAt": Timestamp()
            ])
            print("💾 Feed guardado en caché")
        } catch {
            print("⚠️ Error guardando caché: \(error.localizedDescription)")
        }
    }
    
    /// Invalida el caché del usuario. Llámalo cuando cambian sus gustos.
    func invalidateFeedCache() {
        guard let userId = currentUserId else { return }
        
        Task {
            do {
                try await db.collection("feedCache").document(userId).delete()
                print("🗑️ Caché de feed invalidado")
            } catch {
                print("⚠️ Error invalidando caché: \(error.localizedDescription)")
            }
        }
    }
}
