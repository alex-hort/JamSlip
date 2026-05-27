//
//  SubscriptionSyncService.swift
//  Splash Screen
//
//  Created by Alexis Horteales Espinosa on 06/02/26.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore
import Combine

// MARK: - Subscription Sync Service
/// Servicio para sincronizar estado de suscripción con Firebase
/// IMPORTANTE: Firebase es solo para UI/features, NO para validación de compras
@MainActor
final class SubscriptionSyncService: ObservableObject {
    
    // MARK: - Singleton
    static let shared = SubscriptionSyncService()
    
    // MARK: - Properties
    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    
    // MARK: - Published
    @Published private(set) var cachedInfo: SubscriptionInfo?
    
    private init() {
        setupAuthListener()
    }
    
    // MARK: - Auth Listener
    private func setupAuthListener() {
        Auth.auth().addStateDidChangeListener { [weak self] _, user in
            if let user = user {
                self?.startListening(for: user.uid)
                
                // ✅ Sincronizar cuando Auth confirme la sesión
                Task {
                    let info = StoreKitManager.shared.subscriptionInfo
                    await self?.syncToFirebase(info: info)
                }
            } else {
                self?.stopListening()
                self?.cachedInfo = nil
            }
        }
    }
    
    // MARK: - Sync to Firebase
    func syncToFirebase(info: SubscriptionInfo) async {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("⚠️ No hay usuario autenticado para sincronizar")
            return
        }
        
        let data: [String: Any] = [
            "status": info.status.rawValue,
            "productId": info.productId ?? "",
            "originalTransactionId": info.originalTransactionId ?? "",
            "purchaseDate": info.purchaseDate ?? Date(),
            "expirationDate": info.expirationDate ?? Date(),
            "isInTrialPeriod": info.isInTrialPeriod,
            "willAutoRenew": info.willAutoRenew,
            "lastVerifiedAt": info.lastVerifiedAt,
            "updatedAt": FieldValue.serverTimestamp()
        ]
        
        do {
            // Guardar en subcolección de subscription
            try await db.collection("users")
                .document(userId)
                .collection("subscription")
                .document("current")
                .setData(data, merge: true)
            
            // ✅ CORREGIDO: Usar setData en lugar de updateData
            try await db.collection("users")
                .document(userId)
                .setData([
                    "isPremium": info.status.isActive,
                    "premiumExpiresAt": info.expirationDate ?? NSNull(),
                    "isInTrialPeriod": info.isInTrialPeriod
                ], merge: true) // ✅ merge: true permite crear o actualizar
            
            print("✅ Suscripción sincronizada con Firebase")
            
        } catch {
            print("❌ Error sincronizando con Firebase: \(error)")
        }
    }
    
    // MARK: - Start Listening
    private func startListening(for userId: String) {
        stopListening()
        
        listener = db.collection("users")
            .document(userId)
            .collection("subscription")
            .document("current")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let data = snapshot?.data() else { return }
                
                self?.cachedInfo = SubscriptionInfo(
                    status: SubscriptionStatus(rawValue: data["status"] as? String ?? "") ?? .notSubscribed,
                    productId: data["productId"] as? String,
                    originalTransactionId: data["originalTransactionId"] as? String,
                    purchaseDate: (data["purchaseDate"] as? Timestamp)?.dateValue(),
                    expirationDate: (data["expirationDate"] as? Timestamp)?.dateValue(),
                    isInTrialPeriod: data["isInTrialPeriod"] as? Bool ?? false,
                    willAutoRenew: data["willAutoRenew"] as? Bool ?? false,
                    lastVerifiedAt: (data["lastVerifiedAt"] as? Timestamp)?.dateValue() ?? Date()
                )
            }
    }
    
    private func stopListening() {
        listener?.remove()
        listener = nil
    }
    
    // MARK: - Record Trial Usage
    func recordTrialUsage() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        do {
            try await db.collection("users")
                .document(userId)
                .collection("subscription")
                .document("history")
                .setData([
                    "hasUsedTrial": true,
                    "trialStartDate": FieldValue.serverTimestamp()
                ], merge: true)
            
            print("✅ Trial registrado")
            
        } catch {
            print("❌ Error registrando trial: \(error)")
        }
    }
    
    // MARK: - Check Trial Eligibility
    func hasUsedTrialBefore() async -> Bool {
        guard let userId = Auth.auth().currentUser?.uid else {
            return true // Sin sesión = bloquear
        }
        
        do {
            let doc = try await db.collection("users")
                .document(userId)
                .collection("subscription")
                .document("history")
                .getDocument()
            
            return doc.data()?["hasUsedTrial"] as? Bool ?? false
            
        } catch {
            return true // Error de red = bloquear por seguridad
        }
    }
    
    // MARK: - Log Subscription Event
    func logSubscriptionEvent(event: SubscriptionEvent) async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        let eventData: [String: Any] = [
            "type": event.type.rawValue,
            "productId": event.productId ?? "",
            "timestamp": FieldValue.serverTimestamp(),
            "metadata": event.metadata
        ]
        
        do {
            try await db.collection("users")
                .document(userId)
                .collection("subscription")
                .document("events")
                .collection("log")
                .addDocument(data: eventData)
            
        } catch {
            print("❌ Error logging event: \(error)")
        }
    }
}

// MARK: - Subscription Event
struct SubscriptionEvent {
    enum EventType: String {
        case purchased = "purchased"
        case renewed = "renewed"
        case cancelled = "cancelled"
        case expired = "expired"
        case restored = "restored"
        case trialStarted = "trial_started"
        case trialEnded = "trial_ended"
    }
    
    let type: EventType
    let productId: String?
    let metadata: [String: Any]
    
    static func purchased(productId: String, isTrialPeriod: Bool) -> SubscriptionEvent {
        SubscriptionEvent(
            type: isTrialPeriod ? .trialStarted : .purchased,
            productId: productId,
            metadata: ["isTrialPeriod": isTrialPeriod]
        )
    }
    
    static func expired(productId: String) -> SubscriptionEvent {
        SubscriptionEvent(type: .expired, productId: productId, metadata: [:])
    }
    
    static func restored(productId: String) -> SubscriptionEvent {
        SubscriptionEvent(type: .restored, productId: productId, metadata: [:])
    }
}

// MARK: - Premium Check Extension
extension SubscriptionSyncService {
    
    /// Verifica si el usuario tiene acceso premium
    var isPremium: Bool {
        // Primero verificar con StoreKit (fuente de verdad)
        if StoreKitManager.shared.isSubscribed {
            return true
        }
        
        // Fallback a cache de Firebase
        if let cached = cachedInfo, cached.status.isActive {
            if let expDate = cached.expirationDate, expDate > Date() {
                return true
            }
        }
        
        return false
    }
}
