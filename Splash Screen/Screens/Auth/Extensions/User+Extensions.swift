//
//  User+Extensions.swift
//  Splash Screen
//
//  Created by Alexis Horteales Espinosa on 15/01/26.
//

import Foundation

// MARK: - User Hashable Extension
// Necesario para usar User con NavigationPath

extension User: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(uid)
    }
}
