//
//  User.swift
//  Splash Screen
//
//  Created by Alexis Horteales Espinosa on 05/01/26.
//
import Foundation
import FirebaseFirestore

struct User: Codable, Equatable {
    let uid: String
    let email: String
    let fullName: String
    let username: String
    var bio: String?
    var profileImageUrl: String?
    var bannerImageUrl: String?
    var joinedDate: Date?
    var followingCount: Int?
    var followersCount: Int?
    var jamsCount: Int?
    
    // MARK: - Premium Properties
    var _isPremium: Bool?
    var _premiumExpiresAt: Date?
    var _isInTrialPeriod: Bool?
    
    /// Indica si el usuario tiene suscripción premium activa
    var isPremium: Bool {
        // ✅ VALIDACIÓN ESTRICTA:
        
        // 1. Si el campo no existe en Firebase, NO es premium
        guard let isPremium = _isPremium else {
            return false
        }
        
        // 2. Si el campo es false, NO es premium
        guard isPremium else {
            return false
        }
        
        // 3. Si es true, DEBE tener fecha de expiración válida
        guard let expiresAt = _premiumExpiresAt else {
            // isPremium = true pero SIN fecha de expiración = INVÁLIDO
            print("⚠️ Usuario \(uid) tiene isPremium=true pero sin fecha de expiración")
            return false
        }
        
        // 4. Verificar que la fecha NO haya expirado
        let isValid = expiresAt > Date()
        
        if !isValid {
            print("⏰ Premium expirado para usuario \(uid)")
        }
        
        return isValid
    }
    
    /// Indica si está en período de prueba
    var isInTrialPeriod: Bool {
        // Solo es trial si:
        // 1. El campo existe y es true
        guard let isTrial = _isInTrialPeriod, isTrial else {
            return false
        }
        
        // 2. Tiene fecha de expiración válida
        guard let expiresAt = _premiumExpiresAt else {
            return false
        }
        
        // 3. La fecha no ha expirado
        return expiresAt > Date()
    }
    
    // MARK: - Init
    init(
        uid: String,
        email: String,
        fullName: String,
        username: String,
        bio: String? = nil,
        profileImageUrl: String? = nil,
        bannerImageUrl: String? = nil,
        joinedDate: Date? = Date(),
        followingCount: Int? = 0,
        followersCount: Int? = 0,
        jamsCount: Int? = 0,
        isPremium: Bool? = nil, // ✅ nil por defecto
        premiumExpiresAt: Date? = nil,
        isInTrialPeriod: Bool? = nil // ✅ nil por defecto
    ) {
        self.uid = uid
        self.email = email
        self.fullName = fullName
        self.username = username
        self.bio = bio
        self.profileImageUrl = profileImageUrl
        self.bannerImageUrl = bannerImageUrl
        self.joinedDate = joinedDate
        self.followingCount = followingCount
        self.followersCount = followersCount
        self.jamsCount = jamsCount
        self._isPremium = isPremium
        self._premiumExpiresAt = premiumExpiresAt
        self._isInTrialPeriod = isInTrialPeriod
    }
    
    // MARK: - Coding Keys
    enum CodingKeys: String, CodingKey {
        case uid
        case email
        case fullName
        case username
        case bio
        case profileImageUrl
        case bannerImageUrl
        case joinedDate
        case followingCount
        case followersCount
        case jamsCount
        case _isPremium = "isPremium"
        case _premiumExpiresAt = "premiumExpiresAt"
        case _isInTrialPeriod = "isInTrialPeriod"
    }
    
    // MARK: - Formatted Properties
    
    var formattedJoinDate: String {
        guard let date = joinedDate else { return "Joined recently" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return "Joined \(formatter.string(from: date))"
    }
    
    var formattedFollowersCount: String {
        guard let count = followersCount else { return "0" }
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        }
        return "\(count)"
    }
    
    var formattedFollowingCount: String {
        guard let count = followingCount else { return "0" }
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        }
        return "\(count)"
    }
    
    var formattedPremiumExpiration: String? {
        guard let date = _premiumExpiresAt else { return nil }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.locale = Locale(identifier: "es_MX")
        return formatter.string(from: date)
    }
    
    var daysUntilPremiumExpires: Int? {
        guard let expDate = _premiumExpiresAt else { return nil }
        let days = Calendar.current.dateComponents([.day], from: Date(), to: expDate).day
        return max(0, days ?? 0)
    }
}

// MARK: - Firestore Helpers
extension User {
    
    static func from(document: DocumentSnapshot) -> User? {
        guard let data = document.data() else { return nil }
        return from(data: data, uid: document.documentID)
    }
    
    static func from(data: [String: Any], uid: String? = nil) -> User? {
        guard let email = data["email"] as? String,
              let fullName = data["fullName"] as? String,
              let username = data["username"] as? String else {
            return nil
        }
        
        let id = uid ?? data["uid"] as? String ?? ""
        
        var joinedDate: Date? = nil
        if let timestamp = data["joinedDate"] as? Timestamp {
            joinedDate = timestamp.dateValue()
        }
        
        var premiumExpiresAt: Date? = nil
        if let timestamp = data["premiumExpiresAt"] as? Timestamp {
            premiumExpiresAt = timestamp.dateValue()
        }
        
        // ✅ CRÍTICO: Solo asignar valores si existen en Firebase
        // Si no existen, dejar como nil
        let isPremium: Bool? = data["isPremium"] as? Bool
        let isInTrialPeriod: Bool? = data["isInTrialPeriod"] as? Bool
        
        return User(
            uid: id,
            email: email,
            fullName: fullName,
            username: username,
            bio: data["bio"] as? String,
            profileImageUrl: data["profileImageUrl"] as? String,
            bannerImageUrl: data["bannerImageUrl"] as? String,
            joinedDate: joinedDate,
            followingCount: data["followingCount"] as? Int ?? 0,
            followersCount: data["followersCount"] as? Int ?? 0,
            jamsCount: data["jamsCount"] as? Int ?? 0,
            isPremium: isPremium, // nil si no existe
            premiumExpiresAt: premiumExpiresAt,
            isInTrialPeriod: isInTrialPeriod // nil si no existe
        )
    }
    
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "uid": uid,
            "email": email,
            "fullName": fullName,
            "username": username,
            "followingCount": followingCount ?? 0,
            "followersCount": followersCount ?? 0,
            "jamsCount": jamsCount ?? 0
        ]
        
        // ✅ CRÍTICO: Solo incluir campos premium si tienen valor
        // NO incluir isPremium: false por defecto
        if let isPremium = _isPremium {
            dict["isPremium"] = isPremium
        }
        
        if let isInTrialPeriod = _isInTrialPeriod {
            dict["isInTrialPeriod"] = isInTrialPeriod
        }
        
        if let bio = bio { dict["bio"] = bio }
        if let profileImageUrl = profileImageUrl { dict["profileImageUrl"] = profileImageUrl }
        if let bannerImageUrl = bannerImageUrl { dict["bannerImageUrl"] = bannerImageUrl }
        if let joinedDate = joinedDate { dict["joinedDate"] = Timestamp(date: joinedDate) }
        if let premiumExpiresAt = _premiumExpiresAt { dict["premiumExpiresAt"] = Timestamp(date: premiumExpiresAt) }
        
        return dict
    }
}
