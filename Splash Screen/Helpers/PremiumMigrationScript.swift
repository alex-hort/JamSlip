//
//  PremiumMigrationScript.swift
//  Splash Screen
//
//  Created by Alexis Horteales Espinosa on 07/02/26.
//

import Foundation
import FirebaseFirestore

// ⚠️ SCRIPT DE MIGRACIÓN - EJECUTAR UNA SOLA VEZ
// Este script limpia usuarios que tienen isPremium = false o sin fecha de expiración válida

class PremiumMigrationScript {
    
    static func cleanupInvalidPremiumUsers() async {
        let db = Firestore.firestore()
        
        print("🔧 Iniciando limpieza de usuarios premium...")
        
        do {
            // 1. Obtener todos los usuarios
            let snapshot = try await db.collection("users").getDocuments()
            
            var cleanedCount = 0
            var keptPremiumCount = 0
            
            for doc in snapshot.documents {
                let data = doc.data()
                let userId = doc.documentID
                
                // Verificar si tiene campos premium
                guard let isPremium = data["isPremium"] as? Bool else {
                    // No tiene campo premium - está bien, skip
                    continue
                }
                
                // Si isPremium es false, eliminar el campo
                if !isPremium {
                    try await db.collection("users").document(userId).updateData([
                        "isPremium": FieldValue.delete(),
                        "isInTrialPeriod": FieldValue.delete(),
                        "premiumExpiresAt": FieldValue.delete()
                    ])
                    print("🧹 Limpiado usuario: \(userId) (isPremium era false)")
                    cleanedCount += 1
                    continue
                }
                
                // Si isPremium es true, verificar fecha de expiración
                if isPremium {
                    if let timestamp = data["premiumExpiresAt"] as? Timestamp {
                        let expiresAt = timestamp.dateValue()
                        
                        if expiresAt < Date() {
                            // Expiró - limpiar
                            try await db.collection("users").document(userId).updateData([
                                "isPremium": FieldValue.delete(),
                                "isInTrialPeriod": FieldValue.delete(),
                                "premiumExpiresAt": FieldValue.delete()
                            ])
                            print("🧹 Limpiado usuario: \(userId) (premium expirado)")
                            cleanedCount += 1
                        } else {
                            // Válido - mantener
                            keptPremiumCount += 1
                            print("✅ Usuario premium válido: \(userId)")
                        }
                    } else {
                        // isPremium = true pero sin fecha - limpiar
                        try await db.collection("users").document(userId).updateData([
                            "isPremium": FieldValue.delete(),
                            "isInTrialPeriod": FieldValue.delete(),
                            "premiumExpiresAt": FieldValue.delete()
                        ])
                        print("🧹 Limpiado usuario: \(userId) (sin fecha de expiración)")
                        cleanedCount += 1
                    }
                }
            }
            
            print("✅ Migración completada:")
            print("   - Usuarios limpiados: \(cleanedCount)")
            print("   - Usuarios premium válidos: \(keptPremiumCount)")
            
        } catch {
            print("❌ Error en migración: \(error)")
        }
    }
    
    // ALTERNATIVA: Limpiar TODOS los usuarios (usar con cuidado)
    static func removeAllPremiumFields() async {
        let db = Firestore.firestore()
        
        print("⚠️ ATENCIÓN: Removiendo TODOS los campos premium...")
        
        do {
            let snapshot = try await db.collection("users").getDocuments()
            
            for doc in snapshot.documents {
                try await db.collection("users").document(doc.documentID).updateData([
                    "isPremium": FieldValue.delete(),
                    "isInTrialPeriod": FieldValue.delete(),
                    "premiumExpiresAt": FieldValue.delete()
                ])
                print("🧹 Limpiado: \(doc.documentID)")
            }
            
            print("✅ Todos los campos premium removidos")
            
        } catch {
            print("❌ Error: \(error)")
        }
    }
}

// MARK: - Cómo usar este script
/*
 
 EN TU APP DELEGATE O VISTA DE ADMIN:
 
 Task {
     // Opción 1: Limpiar solo usuarios inválidos (RECOMENDADO)
     await PremiumMigrationScript.cleanupInvalidPremiumUsers()
     
     // Opción 2: Limpiar TODOS (usar solo si quieres resetear todo)
     // await PremiumMigrationScript.removeAllPremiumFields()
 }
 
 ⚠️ IMPORTANTE:
 1. Ejecutar SOLO UNA VEZ
 2. Hacer backup de Firebase antes
 3. Verificar resultados en Firebase Console
 
 */
