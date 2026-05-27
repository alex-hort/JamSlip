//
//  SubscriptionStatus.swift
//  Splash Screen
//
//  Created by Alexis Horteales Espinosa on 06/02/26.
//
import Foundation

// MARK: - Subscription Status
/// Representa el estado actual de la suscripción del usuario
enum SubscriptionStatus: String, Codable {
    case notSubscribed = "not_subscribed"
    case subscribed = "subscribed"
    case expired = "expired"
    case inGracePeriod = "in_grace_period"
    case inBillingRetry = "in_billing_retry"
    case revoked = "revoked"
    
    var isActive: Bool {
        switch self {
        case .subscribed, .inGracePeriod, .inBillingRetry:
            return true
        case .notSubscribed, .expired, .revoked:
            return false
        }
    }
    
    var displayName: String {
        switch self {
        case .notSubscribed: return "Not Subscribed"
        case .subscribed: return "Premium Active"
        case .expired: return "Expired"
        case .inGracePeriod: return "Grace Period"
        case .inBillingRetry: return "Retrying Payment"
        case .revoked: return "Revoked"
        }
    }
}

// MARK: - Subscription Info
struct SubscriptionInfo: Codable {
    let status: SubscriptionStatus
    let productId: String?
    let originalTransactionId: String?
    let purchaseDate: Date?
    let expirationDate: Date?
    let isInTrialPeriod: Bool
    let willAutoRenew: Bool
    let lastVerifiedAt: Date
    
    var isTrialActive: Bool {
        guard isInTrialPeriod, let expDate = expirationDate else { return false }
        return expDate > Date()
    }
    
    var isYearlyPlan: Bool {
        return productId == SubscriptionProduct.yearlyPremium
    }
    
    var isMonthlyPlan: Bool {
        return productId == SubscriptionProduct.monthlyPremium
    }
    
    var daysRemaining: Int? {
        guard let expDate = expirationDate else { return nil }
        let days = Calendar.current.dateComponents([.day], from: Date(), to: expDate).day
        return max(0, days ?? 0)
    }
    
    static var empty: SubscriptionInfo {
        SubscriptionInfo(
            status: .notSubscribed,
            productId: nil,
            originalTransactionId: nil,
            purchaseDate: nil,
            expirationDate: nil,
            isInTrialPeriod: false,
            willAutoRenew: false,
            lastVerifiedAt: Date()
        )
    }
}

// MARK: - Product Identifiers
enum SubscriptionProduct {
    // Producto mensual - $99 MXN
    static let monthlyPremium = "alexhort.Splash-Screen.premium.monthly"
    
    // Producto anual - $1,000 MXN ($83.33/mes)
    static let yearlyPremium = "alexhort.Splash-Screen.premium.yearly"
    
    // Grupo de suscripción
    static let groupId = "premium_subscription_group"
    
    static var allProducts: [String] {
        [monthlyPremium, yearlyPremium]
    }
}

// MARK: - Plan Type
enum PlanType: String, CaseIterable {
    case yearly = "yearly"
    case monthly = "monthly"
    
    var displayName: String {
        switch self {
        case .yearly: return "Yearly"
        case .monthly: return "Monthly"
        }
    }
    
    var price: String {
        switch self {
        case .yearly: return "$1,000 MXN"
        case .monthly: return "$99 MXN"
        }
    }
    
    var pricePerMonth: String {
        switch self {
        case .yearly: return "$83.33 MXN"
        case .monthly: return "$99 MXN"
        }
    }
    
    var savings: String? {
        switch self {
        case .yearly: return "Save $188 MXN/year"
        case .monthly: return nil
        }
    }
    
    var productId: String {
        switch self {
        case .yearly: return SubscriptionProduct.yearlyPremium
        case .monthly: return SubscriptionProduct.monthlyPremium
        }
    }
}

// MARK: - Premium Features
enum PremiumFeature: String, CaseIterable {
    case verifiedBadge = "verified_badge"
    case feedVisibility = "feed_visibility"
    case spatialAudio = "spatial_audio"
    case unlimitedUploads = "unlimited_uploads"
    
    var title: String {
        switch self {
        case .verifiedBadge: return "Verified Profile"
        case .feedVisibility: return "Greater Visibility"
        case .spatialAudio: return "Spatial Audio"
        case .unlimitedUploads: return "Unlimited Uploads"
        }
    }

    var description: String {
        switch self {
        case .verifiedBadge: return "Exclusive badge on your profile"
        case .feedVisibility: return "Your jams appear first"
        case .spatialAudio: return "Immersive 3D audio"
        case .unlimitedUploads: return "Upload as many jams as you want"
        }
    }
    
    var icon: String {
        switch self {
        case .verifiedBadge: return "checkmark.seal.fill"
        case .feedVisibility: return "arrow.up.circle.fill"
        case .spatialAudio: return "ear.fill"
        case .unlimitedUploads: return "icloud.and.arrow.up.fill"
        }
    }
    
    var iconColor: Color {
        switch self {
        case .verifiedBadge: return .purple
        case .feedVisibility: return .blue
        case .spatialAudio: return .orange
        case .unlimitedUploads: return .green
        }
    }
}

import SwiftUI

// MARK: - Purchase Error
enum PurchaseError: LocalizedError {
    case productNotFound
    case purchaseFailed
    case purchaseCancelled
    case purchasePending
    case verificationFailed
    case networkError
    case unknown(Error)
    
    var errorDescription: String? {
        switch self {
        case .productNotFound: return "Producto no encontrado"
        case .purchaseFailed: return "La compra falló. Intenta de nuevo."
        case .purchaseCancelled: return "Compra cancelada"
        case .purchasePending: return "Compra pendiente de aprobación"
        case .verificationFailed: return "No se pudo verificar la compra"
        case .networkError: return "Error de conexión"
        case .unknown(let error): return error.localizedDescription
        }
    }
}
