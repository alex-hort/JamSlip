//
//  StoreKitManager.swift
//  Splash Screen
//
//  Created by Alexis Horteales Espinosa on 06/02/26.
//
import Foundation
import StoreKit
import Combine

// MARK: - StoreKit Manager PRODUCTION
@MainActor
final class StoreKitManager: ObservableObject {
    
    static let shared = StoreKitManager()
    
//    private let debugMode = true// ⚠️ CAMBIAR A false PARA PRODUCCIÓN
    // ✅ Correcto
    private let debugMode: Bool = {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }()
    
    // MARK: - UserDefaults Keys
    private enum StorageKeys {
        static let subscriptionStatus = "premium_subscription_status"
        static let subscriptionProductId = "premium_product_id"
        static let subscriptionPurchaseDate = "premium_purchase_date"
        static let subscriptionExpirationDate = "premium_expiration_date"
        static let subscriptionIsTrialPeriod = "premium_is_trial"
        static let subscriptionTransactionId = "premium_transaction_id"
        static let hasEverSubscribed = "has_ever_subscribed"
        static let lastVerificationDate = "last_verification_date"
    }
    
    // MARK: - Published Properties
    @Published private(set) var products: [Product] = []
    @Published private(set) var subscriptionInfo: SubscriptionInfo = .empty
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var isVerified = false
    
    // MARK: - ✅ COMPUTED PROPERTY CRÍTICO
    var isSubscribed: Bool {
        // ✅ Si no ha verificado PERO tiene caché válido, confiar en caché
        if !isVerified {
            // Verificar si hay caché válido
            if subscriptionInfo.status.isActive,
               let expirationDate = subscriptionInfo.expirationDate,
               expirationDate > Date() {
                // Caché válido - confiar temporalmente
                return true
            }
            return false
        }
        
        // ✅ Verificar estado activo
        guard subscriptionInfo.status.isActive else {
            return false
        }
        
        // ✅ Verificar fecha de expiración
        if let expirationDate = subscriptionInfo.expirationDate {
            return expirationDate > Date()
        }
        
        return false
    }
    
    var monthlyProduct: Product? {
        products.first { $0.id == SubscriptionProduct.monthlyPremium }
    }
    
    var yearlyProduct: Product? {
        products.first { $0.id == SubscriptionProduct.yearlyPremium }
    }
    
    private var updateListenerTask: Task<Void, Error>?
    private var productIds: [String] = SubscriptionProduct.allProducts
    
    // MARK: - ✅ INIT OPTIMIZADO
    private init() {
        // ✅ PASO 1: Cargar INMEDIATAMENTE desde caché (sincrónico)
        loadFromCache()
        
        print("🚀 StoreKit inicializado - Estado: \(subscriptionInfo.status.displayName)")
        
        // ✅ PASO 2: Verificar en background (asíncrono)
        Task {
            await verifySubscriptionStatus()
        }
        
        // ✅ PASO 3: Inicializar StoreKit
        updateListenerTask = listenForTransactions()
        Task {
            await loadProducts()
        }
    }
    
    deinit {
        updateListenerTask?.cancel()
    }
    
    // MARK: - ✅ CARGAR DESDE CACHÉ (INSTANTÁNEO)
    private func loadFromCache() {
        let defaults = UserDefaults.standard
        
        // Si nunca ha suscrito, mantener FREE
        guard defaults.bool(forKey: StorageKeys.hasEverSubscribed) else {
            print("👤 Usuario nuevo - FREE")
            subscriptionInfo = .empty
            isVerified = true
            return
        }
        
        // Verificar que tenga datos válidos
        guard let statusRaw = defaults.string(forKey: StorageKeys.subscriptionStatus),
              let status = SubscriptionStatus(rawValue: statusRaw),
              let expirationDate = defaults.object(forKey: StorageKeys.subscriptionExpirationDate) as? Date else {
            print("⚠️ Caché corrupto - FREE por defecto")
            subscriptionInfo = .empty
            isVerified = true
            return
        }
        
        // ✅ VALIDACIÓN INMEDIATA DE EXPIRACIÓN
        if expirationDate < Date() {
            print("⏰ Suscripción expirada (caché)")
            subscriptionInfo = .empty
            clearCache()
            isVerified = true
            return
        }
        
        // ✅ Restaurar desde caché
        let productId = defaults.string(forKey: StorageKeys.subscriptionProductId)
        let transactionId = defaults.string(forKey: StorageKeys.subscriptionTransactionId)
        let purchaseDate = defaults.object(forKey: StorageKeys.subscriptionPurchaseDate) as? Date
        let isTrialPeriod = defaults.bool(forKey: StorageKeys.subscriptionIsTrialPeriod)
        let lastVerification = defaults.object(forKey: StorageKeys.lastVerificationDate) as? Date ?? Date.distantPast
        
        subscriptionInfo = SubscriptionInfo(
            status: status,
            productId: productId,
            originalTransactionId: transactionId,
            purchaseDate: purchaseDate,
            expirationDate: expirationDate,
            isInTrialPeriod: isTrialPeriod,
            willAutoRenew: true,
            lastVerifiedAt: lastVerification
        )
        
        // ✅ CONFIAR EN CACHÉ hasta que se verifique
        isVerified = true
        
        let daysSinceVerification = Calendar.current.dateComponents([.day], from: lastVerification, to: Date()).day ?? 0
        print("💾 Cargado desde caché: \(status.displayName)")
        print("   Expira: \(expirationDate)")
        print("   Verificado hace: \(daysSinceVerification) días")
    }
    
    // MARK: - ✅ VERIFICAR ESTADO (BACKGROUND)
    func verifySubscriptionStatus() async {
        print("🔍 Verificando estado de suscripción...")
        
        if debugMode {
            // ✅ En debug, solo marcar como verificado y mantener caché
            await MainActor.run {
                isVerified = true
                print("🧪 Debug: Confiando en caché local")
            }
            return
        }
        
        // ✅ Verificar con StoreKit (modo producción)
        var hasActiveSubscription = false
        var latestInfo = SubscriptionInfo.empty
        
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                guard transaction.productType == .autoRenewable else { continue }
                
                // Verificar que no esté revocada
                if transaction.revocationDate != nil {
                    print("⚠️ Transacción revocada")
                    continue
                }
                
                // Verificar que no esté expirada
                if let expirationDate = transaction.expirationDate,
                   expirationDate < Date() {
                    print("⚠️ Transacción expirada")
                    continue
                }
                
                // ✅ Encontramos una suscripción activa
                hasActiveSubscription = true
                
                let renewalInfo = await getSubscriptionRenewalInfo(for: transaction)
                let status = determineSubscriptionStatus(transaction: transaction, renewalInfo: renewalInfo)
                
                latestInfo = SubscriptionInfo(
                    status: status,
                    productId: transaction.productID,
                    originalTransactionId: String(transaction.originalID),
                    purchaseDate: transaction.purchaseDate,
                    expirationDate: transaction.expirationDate,
                    isInTrialPeriod: transaction.offerType == .introductory,
                    willAutoRenew: renewalInfo?.willAutoRenew ?? false,
                    lastVerifiedAt: Date()
                )
                
                print("✅ Suscripción activa encontrada: \(transaction.productID)")
                break
                
            } catch {
                print("❌ Error verificando transacción: \(error)")
            }
        }
        
        // ✅ Actualizar estado
        await MainActor.run {
            if hasActiveSubscription {
                self.subscriptionInfo = latestInfo
                self.saveToCache(latestInfo)
                print("✅ Suscripción activa verificada y guardada")
            } else {
                // ⚠️ Si no hay suscripción en StoreKit pero había caché válido
                if self.subscriptionInfo.status.isActive,
                   let expDate = self.subscriptionInfo.expirationDate,
                   expDate > Date() {
                    print("⚠️ No se encontró en StoreKit pero caché es válido - mantener caché")
                    // Mantener el caché existente
                } else {
                    self.subscriptionInfo = .empty
                    self.clearCache()
                    print("✅ Sin suscripción activa")
                }
            }
            
            self.isVerified = true
            
            // Sincronizar con Firebase
            Task {
                await SubscriptionSyncService.shared.syncToFirebase(info: self.subscriptionInfo)
            }
        }
    }
    
    // MARK: - ✅ GUARDAR EN CACHÉ
    private func saveToCache(_ info: SubscriptionInfo) {
        let defaults = UserDefaults.standard
        
        guard let expirationDate = info.expirationDate,
              expirationDate > Date() else {
            print("⚠️ No se puede guardar suscripción sin fecha válida")
            return
        }
        
        defaults.set(info.status.rawValue, forKey: StorageKeys.subscriptionStatus)
        defaults.set(info.productId, forKey: StorageKeys.subscriptionProductId)
        defaults.set(info.originalTransactionId, forKey: StorageKeys.subscriptionTransactionId)
        defaults.set(info.purchaseDate, forKey: StorageKeys.subscriptionPurchaseDate)
        defaults.set(info.expirationDate, forKey: StorageKeys.subscriptionExpirationDate)
        defaults.set(info.isInTrialPeriod, forKey: StorageKeys.subscriptionIsTrialPeriod)
        defaults.set(Date(), forKey: StorageKeys.lastVerificationDate)
        defaults.set(true, forKey: StorageKeys.hasEverSubscribed)
        defaults.synchronize() // ✅ FORZAR GUARDADO INMEDIATO
        
        print("💾 Caché guardado - Expira: \(expirationDate)")
    }
    
    // MARK: - ✅ LIMPIAR CACHÉ
    private func clearCache() {
        let defaults = UserDefaults.standard
        
        defaults.removeObject(forKey: StorageKeys.subscriptionStatus)
        defaults.removeObject(forKey: StorageKeys.subscriptionProductId)
        defaults.removeObject(forKey: StorageKeys.subscriptionTransactionId)
        defaults.removeObject(forKey: StorageKeys.subscriptionPurchaseDate)
        defaults.removeObject(forKey: StorageKeys.subscriptionExpirationDate)
        defaults.removeObject(forKey: StorageKeys.subscriptionIsTrialPeriod)
        defaults.removeObject(forKey: StorageKeys.lastVerificationDate)
        defaults.synchronize() // ✅ FORZAR GUARDADO
        
        print("🗑️ Caché limpiado")
    }
    
    // MARK: - Load Products
    func loadProducts() async {
        isLoading = true
        errorMessage = nil
        
        if debugMode {
            print("🧪 DEBUG: Productos simulados")
            isLoading = false
            return
        }
        
        do {
            let storeProducts = try await Product.products(for: productIds)
            products = storeProducts.filter { $0.type == .autoRenewable }
            print("✅ Productos cargados: \(products.count)")
        } catch {
            print("❌ Error cargando productos: \(error)")
            errorMessage = "No se pudieron cargar los productos"
        }
        
        isLoading = false
    }
    
    // MARK: - Purchase
    func purchase(_ product: Product) async throws -> Transaction? {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        do {
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await verifySubscriptionStatus() // ✅ Re-verificar inmediatamente
                await transaction.finish()
                print("✅ Compra exitosa")
                return transaction
            case .userCancelled:
                throw PurchaseError.purchaseCancelled
            case .pending:
                throw PurchaseError.purchasePending
            @unknown default:
                throw PurchaseError.unknown(NSError(domain: "StoreKit", code: -1))
            }
        } catch let error as PurchaseError {
            errorMessage = error.localizedDescription
            throw error
        } catch {
            errorMessage = "Error al procesar la compra"
            throw PurchaseError.unknown(error)
        }
    }
    
    // MARK: - 🧪 DEBUG: Simular Trial
    func debugStartTrial() async {
        guard debugMode else {
            print("⚠️ Debug mode desactivado - usar compra real")
            return
        }
        
        // ✅ Verificar que no haya usado trial antes
        let alreadyUsed = await SubscriptionSyncService.shared.hasUsedTrialBefore()
        guard !alreadyUsed else {
            print("🚫 DEBUG: Usuario ya usó su trial")
            return
        }
        
        isLoading = true
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        let trialInfo = SubscriptionInfo(
            status: .subscribed,
            productId: SubscriptionProduct.monthlyPremium,
            originalTransactionId: "DEBUG_TRIAL_\(UUID().uuidString)",
            purchaseDate: Date(),
            expirationDate: Calendar.current.date(byAdding: .day, value: 3, to: Date()),
            isInTrialPeriod: true,
            willAutoRenew: true,
            lastVerifiedAt: Date()
        )
        
        subscriptionInfo = trialInfo
        saveToCache(trialInfo)
        isVerified = true
        
        print("🧪 DEBUG: Trial de 3 días iniciado")
        
        await SubscriptionSyncService.shared.syncToFirebase(info: trialInfo)
        await SubscriptionSyncService.shared.recordTrialUsage()
        
        isLoading = false
        
        
    }
    
    // MARK: - 🧪 DEBUG: Cancelar
    func debugCancelSubscription() async {
        guard debugMode else { return }
        
        subscriptionInfo = .empty
        clearCache()
        isVerified = true
        
        await SubscriptionSyncService.shared.syncToFirebase(info: .empty)
        print("🧪 DEBUG: Suscripción cancelada")
    }
    
    // MARK: - Restore Purchases
    func restorePurchases() async throws {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        if debugMode {
            loadFromCache()
            if !isSubscribed {
                errorMessage = "No se encontraron compras"
            }
            return
        }
        
        do {
            try await AppStore.sync()
            await verifySubscriptionStatus()
            
            if !isSubscribed {
                errorMessage = "No se encontraron compras"
            } else {
                print("✅ Compras restauradas exitosamente")
            }
        } catch {
            errorMessage = "Error al restaurar"
            throw error
        }
    }
    
    // MARK: - Listen for Transactions
    private func listenForTransactions() -> Task<Void, Error> {
        Task.detached {
            for await result in Transaction.updates {
                do {
                    let transaction = try await self.checkVerified(result)
                    await self.verifySubscriptionStatus()
                    await transaction.finish()
                } catch {
                    print("❌ Error en transaction: \(error)")
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw PurchaseError.verificationFailed
        case .verified(let safe):
            return safe
        }
    }
    
    private func getSubscriptionRenewalInfo(for transaction: Transaction) async -> Product.SubscriptionInfo.RenewalInfo? {
        guard let product = products.first(where: { $0.id == transaction.productID }),
              let subscription = product.subscription else { return nil }
        
        do {
            let statuses = try await subscription.status
            for status in statuses {
                if case .verified(let renewalInfo) = status.renewalInfo {
                    return renewalInfo
                }
            }
        } catch { }
        return nil
    }
    
    private func determineSubscriptionStatus(
        transaction: Transaction,
        renewalInfo: Product.SubscriptionInfo.RenewalInfo?
    ) -> SubscriptionStatus {
        if transaction.revocationDate != nil { return .revoked }
        
        if let expirationDate = transaction.expirationDate {
            if expirationDate < Date() {
                if let renewalInfo = renewalInfo {
                    if renewalInfo.gracePeriodExpirationDate != nil { return .inGracePeriod }
                    if renewalInfo.isInBillingRetry { return .inBillingRetry }
                }
                return .expired
            }
        }
        return .subscribed
    }
    
    func hasAccess(to feature: PremiumFeature) -> Bool {
        return isSubscribed
    }
    
    func getMonthlyPrice() -> String {
        guard let product = monthlyProduct else { return "$99.00" }
        return product.displayPrice
    }
    
    func getYearlyPrice() -> String {
        guard let product = yearlyProduct else { return "$1,000.00" }
        return product.displayPrice
    }
    
    func getYearlyMonthlyPrice() -> String {
        return "$83.33"
    }
    
    func getTrialInfo() async -> (hasTrial: Bool, duration: String)? {
        if debugMode {
            return (hasTrial: true, duration: "3 días")
        }
        
        guard let product = monthlyProduct,
              let subscription = product.subscription else { return nil }
        
        let isEligible = await subscription.isEligibleForIntroOffer
        guard isEligible, let introOffer = subscription.introductoryOffer else { return nil }
        
        let duration: String
        switch introOffer.period.unit {
        case .day: duration = "\(introOffer.period.value) días"
        case .week: duration = "\(introOffer.period.value) semanas"
        case .month: duration = "\(introOffer.period.value) meses"
        case .year: duration = "\(introOffer.period.value) años"
        @unknown default: duration = "período de prueba"
        }
        
        return (hasTrial: true, duration: duration)
    }
}





