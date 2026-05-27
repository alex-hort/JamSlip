//
//  LikedJamsView.swift
//  Splash Screen
//
//  Created by Alexis Horteales Espinosa on 14/01/26.
//
import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import UniformTypeIdentifiers

struct LikedJamsView: View {
    var userId: String? = nil
    
    @StateObject private var userJamsService = UserJamsService.shared
    @StateObject private var myJamsService = MyJamsService.shared
    
    @State private var isLoading = true
    @State private var audiusTracks: [AudiusTrack] = []
    @State private var premiumJams: [Jam] = []
    
    @State private var listener: ListenerRegistration?
    
    // ✅ Estados para drag & drop
    @State private var draggingItem: String? = nil
    
    let spacing: CGFloat = 10
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)
    
    private var displayUserId: String? {
        userId ?? Auth.auth().currentUser?.uid
    }
    
    // ✅ CRÍTICO: Solo permitir reordenar en MI perfil
    private var isOwnProfile: Bool {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return false }
        guard let displayId = displayUserId else { return false }
        return displayId == currentUserId
    }
    
    private var isEmpty: Bool {
        audiusTracks.isEmpty && premiumJams.isEmpty
    }
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .tint(.white)
                    .frame(maxWidth: .infinity, minHeight: 200)
            } else if isEmpty {
                EmptyJamsPlaceholder(
                    icon: "heart",
                    title: "No liked jams yet",
                    subtitle: isOwnProfile ? "Tap the heart on jams you love" : "This user hasn't liked any jams"
                )
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: spacing) {
                        // Premium Jams
                        ForEach(premiumJams) { jam in
                            PremiumJamGridItem(
                                jam: jam,
                                showLikesCount: true,
                                allJams: premiumJams
                            )
                            .opacity(draggingItem == jam.id ? 0.3 : 1.0)
                            .scaleEffect(draggingItem == jam.id ? 1.05 : 1.0)
                            .overlay {
                                // ✅ Shake effect mientras se mueve CUALQUIER item
                                if draggingItem != nil && draggingItem != jam.id {
                                    ShakeEffect()
                                }
                            }
                            .if(isOwnProfile) { view in
                                view
                                    .onDrag {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            self.draggingItem = jam.id
                                        }
                                        
                                        // Haptic feedback
                                        let impact = UIImpactFeedbackGenerator(style: .medium)
                                        impact.impactOccurred()
                                        
                                        return NSItemProvider(object: jam.id as NSString)
                                    }
                                    .onDrop(of: [.text], delegate: LikedPremiumJamDropDelegate(
                                        item: jam,
                                        items: $premiumJams,
                                        draggingItem: $draggingItem,
                                        userId: displayUserId ?? ""
                                    ))
                            }
                        }
                        
                        // Audius Tracks
                        ForEach(audiusTracks) { track in
                            JamGridItem(
                                track: track,
                                showLikesCount: true,
                                allTracks: audiusTracks
                            )
                            .opacity(draggingItem == track.id ? 0.3 : 1.0)
                            .scaleEffect(draggingItem == track.id ? 1.05 : 1.0)
                            .overlay {
                                // ✅ Shake effect mientras se mueve CUALQUIER item
                                if draggingItem != nil && draggingItem != track.id {
                                    ShakeEffect()
                                }
                            }
                            .if(isOwnProfile) { view in
                                view
                                    .onDrag {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            self.draggingItem = track.id
                                        }
                                        
                                        // Haptic feedback
                                        let impact = UIImpactFeedbackGenerator(style: .medium)
                                        impact.impactOccurred()
                                        
                                        return NSItemProvider(object: track.id as NSString)
                                    }
                                    .onDrop(of: [.text], delegate: LikedAudiusTrackDropDelegate(
                                        item: track,
                                        items: $audiusTracks,
                                        draggingItem: $draggingItem,
                                        userId: displayUserId ?? ""
                                    ))
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .background(Color.black)
        .task {
            await loadAll()
            
            if isOwnProfile {
                startRealtimeListener()
            }
        }
        .onDisappear {
            listener?.remove()
            listener = nil
        }
    }
    
    private func startRealtimeListener() {
        guard let uid = displayUserId else { return }
        
        let db = Firestore.firestore()
        
        listener = db.collection("users")
            .document(uid)
            .collection("likedJamsPremium")
            .addSnapshotListener { [self] snapshot, error in
                guard error == nil else {
                    print("❌ Error listener: \(error!)")
                    return
                }
                
                // ✅ NO recargar si estamos arrastrando
                guard draggingItem == nil else {
                    print("⏸️ Listener pausado (arrastrando)")
                    return
                }
                
                Task {
                    await self.reloadPremiumJams()
                }
            }
    }
    
    private func reloadPremiumJams() async {
        guard let uid = displayUserId else { return }
        premiumJams = await fetchLikedPremiumJams(for: uid)
    }
    
    private func loadAll() async {
        guard let uid = displayUserId else {
            isLoading = false
            return
        }
        
        do {
            if isOwnProfile {
                try await userJamsService.fetchLikedTracks()
                audiusTracks = userJamsService.likedTracks
            } else {
                audiusTracks = try await userJamsService.fetchLikedTracks(for: uid)
            }
        } catch {
            print("❌ Error loading Audius liked: \(error)")
        }
        
        premiumJams = await fetchLikedPremiumJams(for: uid)
        
        isLoading = false
    }
    
    private func fetchLikedPremiumJams(for userId: String) async -> [Jam] {
        let db = Firestore.firestore()
        
        do {
            let snapshot = try await db.collection("users")
                .document(userId)
                .collection("likedJamsPremium")
                .getDocuments()
            
            // ✅ Cargar jams con su orden
            var jamsWithOrder: [(jam: Jam, order: Int)] = []
            
            for doc in snapshot.documents {
                if let jamId = doc.data()["jamId"] as? String {
                    let jamDoc = try await db.collection("jamsPremium").document(jamId).getDocument()
                    if let data = jamDoc.data(),
                       let jam = myJamsService.decodeJam(from: data) {
                        // Obtener orden, usar timestamp si no existe
                        let order: Int
                        if let orderValue = doc.data()["order"] as? Int {
                            order = orderValue
                        } else if let timestamp = doc.data()["likedAt"] as? Timestamp {
                            order = Int(timestamp.seconds)
                        } else {
                            order = Int(Date().timeIntervalSince1970)
                        }
                        jamsWithOrder.append((jam, order))
                    }
                }
            }
            
            // ✅ Ordenar por el campo 'order'
            jamsWithOrder.sort { $0.order < $1.order }
            
            return jamsWithOrder.map { $0.jam }
        } catch {
            print("❌ Error fetching liked premium jams: \(error)")
            return []
        }
    }
}

// MARK: - ✅ Drop Delegate Liked Premium (optimizado)
struct LikedPremiumJamDropDelegate: DropDelegate {
    let item: Jam
    @Binding var items: [Jam]
    @Binding var draggingItem: String?
    let userId: String
    
    // ✅ CRÍTICO: Esto quita el símbolo +
    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .move)
    }
    
    func validateDrop(info: DropInfo) -> Bool {
        return true
    }
    
    func dropEntered(info: DropInfo) {
        guard let draggingItem = draggingItem,
              let fromIndex = items.firstIndex(where: { $0.id == draggingItem }),
              let toIndex = items.firstIndex(where: { $0.id == item.id }),
              fromIndex != toIndex else { return }
        
        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
            items.move(fromOffsets: IndexSet(integer: fromIndex), toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex)
        }
    }
    
    func performDrop(info: DropInfo) -> Bool {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            draggingItem = nil
        }
        
        // Haptic feedback al soltar
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
        
        Task {
            await saveNewOrder()
        }
        
        return true
    }
    
    private func saveNewOrder() async {
        let db = Firestore.firestore()
        
        for (index, jam) in items.enumerated() {
            try? await db.collection("users")
                .document(userId)
                .collection("likedJamsPremium")
                .document(jam.id)
                .updateData(["order": index])
        }
        
        print("✅ Orden de liked guardado")
    }
}

// MARK: - ✅ Drop Delegate Liked Audius (optimizado)
struct LikedAudiusTrackDropDelegate: DropDelegate {
    let item: AudiusTrack
    @Binding var items: [AudiusTrack]
    @Binding var draggingItem: String?
    let userId: String
    
    // ✅ CRÍTICO: Esto quita el símbolo +
    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .move)
    }
    
    func validateDrop(info: DropInfo) -> Bool {
        return true
    }
    
    func dropEntered(info: DropInfo) {
        guard let draggingItem = draggingItem,
              let fromIndex = items.firstIndex(where: { $0.id == draggingItem }),
              let toIndex = items.firstIndex(where: { $0.id == item.id }),
              fromIndex != toIndex else { return }
        
        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
            items.move(fromOffsets: IndexSet(integer: fromIndex), toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex)
        }
    }
    
    func performDrop(info: DropInfo) -> Bool {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            draggingItem = nil
        }
        
        // Haptic feedback al soltar
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
        
        Task {
            await saveNewOrder()
        }
        
        return true
    }
    
    private func saveNewOrder() async {
        let db = Firestore.firestore()
        
        for (index, track) in items.enumerated() {
            try? await db.collection("users")
                .document(userId)
                .collection("likedJams")
                .document(track.id)
                .updateData(["order": index])
        }
        
        print("✅ Orden de liked guardado")
    }
}
