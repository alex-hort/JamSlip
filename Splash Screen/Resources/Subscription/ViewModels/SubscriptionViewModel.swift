//
//  SubscriptionViewModel.swift
//  Splash Screen
//
//  Created by Alexis Horteales Espinosa on 06/02/26.
//
import Foundation
import StoreKit
import SwiftUI
import Combine

// MARK: - Subscription ViewModel
@MainActor
final class SubscriptionViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var isLoading = false
    @Published var isPurchasing = false
    @Published var showSuccessAnimation = false
    @Published var errorMessage: String?
    @Published var showError = false
    
    // Trial info
    @Published var hasTrialAvailable = true
    @Published var trialDuration = "3 días"
    
    // MARK: - Dependencies
    private let storeKit = StoreKitManager.shared
    private let syncService = SubscriptionSyncService.shared
    
    // MARK: - Computed Properties
    var isSubscribed: Bool {
        storeKit.isSubscribed
    }
    
    var isVerified: Bool {
        storeKit.isVerified
    }
    
    var subscriptionInfo: SubscriptionInfo {
        storeKit.subscriptionInfo
    }
    
    var expirationDateFormatted: String? {
        guard let date = subscriptionInfo.expirationDate else { return nil }
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.locale = Locale(identifier: "es_MX")
        return formatter.string(from: date)
    }
    
    var daysRemaining: Int? {
        subscriptionInfo.daysRemaining
    }
    
    var statusMessage: String {
        if !isVerified {
            return "Verificando suscripción..."
        }
        
        switch subscriptionInfo.status {
        case .subscribed:
            if subscriptionInfo.isInTrialPeriod {
                if let days = daysRemaining {
                    return "Prueba gratis - \(days) días restantes"
                }
                return "Prueba gratis activa"
            }
            return "Premium activo"
        case .inGracePeriod:
            return "Actualiza tu método de pago"
        case .inBillingRetry:
            return "Verificando pago..."
        case .expired:
            return "Tu suscripción expiró"
        case .revoked:
            return "Suscripción cancelada"
        case .notSubscribed:
            return "Desbloquea todas las funciones"
        }
    }
    
    // MARK: - Init
    init() {
        Task {
            await loadTrialInfo()
        }
    }
    
    // MARK: - Load Trial Info
//    func loadTrialInfo() async {
//        if let trialInfo = await storeKit.getTrialInfo() {
//            hasTrialAvailable = trialInfo.hasTrial
//            trialDuration = trialInfo.duration
//        }
//    }
    
    func loadTrialInfo() async {
        // ✅ Verificar Firebase primero
        let alreadyUsedTrial = await syncService.hasUsedTrialBefore()
        
        if alreadyUsedTrial {
            hasTrialAvailable = false
            trialDuration = ""
            return
        }
        
        // Solo si nunca ha usado trial, verificar elegibilidad StoreKit
        if let trialInfo = await storeKit.getTrialInfo() {
            hasTrialAvailable = trialInfo.hasTrial
            trialDuration = trialInfo.duration
        }
    }
    
    // MARK: - Purchase with Plan Selection
    func purchase(plan: PlanType) async {
        isPurchasing = true
        errorMessage = nil
        
        // En modo debug, usar compra simulada
        let storeKit = StoreKitManager.shared
        
        // Verificar si hay productos reales
        let hasRealProducts = (plan == .yearly && storeKit.yearlyProduct != nil) ||
                             (plan == .monthly && storeKit.monthlyProduct != nil)
        
        if !hasRealProducts {
            // No hay productos reales, usar debug con trial
            await storeKit.debugStartTrial()
            
            if storeKit.isSubscribed {
                showSuccessAnimation = true
                
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
            }
            
            isPurchasing = false
            return
        }
        
        // Hay productos reales, intentar compra real
        guard let product = (plan == .yearly ? storeKit.yearlyProduct : storeKit.monthlyProduct) else {
            errorMessage = "Producto no disponible"
            showError = true
            isPurchasing = false
            return
        }
        
        do {
            let transaction = try await storeKit.purchase(product)
            
            if transaction != nil {
                showSuccessAnimation = true
                
                await syncService.logSubscriptionEvent(
                    event: .purchased(
                        productId: product.id,
                        isTrialPeriod: storeKit.subscriptionInfo.isInTrialPeriod
                    )
                )
                
                if storeKit.subscriptionInfo.isInTrialPeriod {
                    await syncService.recordTrialUsage()
                }
                
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
            }
            
        } catch let error as PurchaseError {
            switch error {
            case .purchaseCancelled:
                break
            case .purchasePending:
                errorMessage = "Tu compra está pendiente de aprobación"
                showError = true
            default:
                errorMessage = error.localizedDescription
                showError = true
            }
        } catch {
            errorMessage = "Error inesperado. Intenta de nuevo."
            showError = true
        }
        
        isPurchasing = false
    }
    
    // MARK: - Restore
    func restorePurchases() async {
        isLoading = true
        errorMessage = nil
        
        do {
            try await storeKit.restorePurchases()
            
            if storeKit.isSubscribed {
                showSuccessAnimation = true
                
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
            } else {
                errorMessage = "No se encontraron compras anteriores"
                showError = true
            }
            
        } catch {
            errorMessage = "Error al restaurar. Intenta de nuevo."
            showError = true
        }
        
        isLoading = false
    }
    
    // MARK: - ✅ CORREGIDO: Refresh Status
    func refreshStatus() async {
        isLoading = true
        await storeKit.verifySubscriptionStatus() // ✅ Nombre correcto
        await loadTrialInfo()
        isLoading = false
    }
    
    // MARK: - Open Subscription Management
    func openSubscriptionManagement() async {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            do {
                try await AppStore.showManageSubscriptions(in: windowScene)
            } catch {
                if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                    await UIApplication.shared.open(url)
                }
            }
        }
    }
    
    // MARK: - Dismiss Success
    func dismissSuccess() {
        showSuccessAnimation = false
    }
    
    // MARK: - Check Feature Access
    func canAccess(_ feature: PremiumFeature) -> Bool {
        return storeKit.hasAccess(to: feature)
    }
}

// MARK: - Premium Gate Modifier
struct PremiumGateModifier: ViewModifier {
    let feature: PremiumFeature
    @ObservedObject var storeKit = StoreKitManager.shared
    @State private var showPaywall = false
    
    func body(content: Content) -> some View {
        content
            .overlay {
                // ✅ Solo mostrar overlay si está verificado como FREE
                if storeKit.isVerified && !storeKit.hasAccess(to: feature) {
                    PremiumLockedOverlay(feature: feature) {
                        showPaywall = true
                    }
                }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
    }
}

// MARK: - Premium Locked Overlay
struct PremiumLockedOverlay: View {
    let feature: PremiumFeature
    let onUnlock: () -> Void
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.8)
            
            VStack(spacing: 16) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.purple)
                
                Text("Función Premium")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text(feature.description)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                
                Button {
                    onUnlock()
                } label: {
                    Text("Desbloquear")
                        .font(.headline)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 40)
            }
            .padding(32)
        }
    }
}

// MARK: - View Extension
extension View {
    func premiumGate(for feature: PremiumFeature) -> some View {
        modifier(PremiumGateModifier(feature: feature))
    }
    
    func showPaywallIfNeeded(isPresented: Binding<Bool>) -> some View {
        sheet(isPresented: isPresented) {
            PaywallView()
        }
    }
}
