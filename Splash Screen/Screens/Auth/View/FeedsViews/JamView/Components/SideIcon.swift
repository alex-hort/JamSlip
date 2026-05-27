//
//  SideIcon.swift
//  Splash Screen
//
//  Created by Alexis Horteales Espinosa on 22/01/26.
//

import SwiftUI

// MARK: - SideIconButton
struct SideIconButton: View {
    let icon: String
    let count: Int
    var color: Color = .white
    var showCount: Bool = true
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 30))
                    .foregroundColor(color)
                    .shadow(color: .black.opacity(0.4), radius: 6)
                
                if showCount {
                    Text(formattedCount)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.4), radius: 6)
                }
            }
        }
    }
    
    private var formattedCount: String {
        if count >= 1000000 {
            return String(format: "%.1fM", Double(count) / 1000000)
        } else if count >= 1000 {
            return String(format: "%.1fK", Double(count) / 1000)
        }
        return "\(count)"
    }
}

