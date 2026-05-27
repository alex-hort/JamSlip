//
//  SideActionButton.swift
//  Splash Screen
//
//  Created by Alexis Horteales Espinosa on 17/01/26.
//

import SwiftUI
// MARK: - SideActionButton (con animación)
struct SideActionButton: View {
    let icon: String
    let count: Int
    let isActive: Bool
    let activeColor: Color
    let showAnim: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                ZStack {
                    Image(systemName: icon)
                        .font(.system(size: 30))
                        .foregroundColor(isActive ? activeColor : .white)
                        .shadow(color: .black.opacity(0.4), radius: 6)
                        .scaleEffect(showAnim ? 1.3 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.5), value: showAnim)
                }
                
                Text(formattedCount)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.4), radius: 6)
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






