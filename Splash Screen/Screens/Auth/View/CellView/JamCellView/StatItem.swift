//
//  StatItem.swift
//  Splash Screen
//
//  Created by Alexis Horteales Espinosa on 22/01/26.
//

import SwiftUI


// MARK: - StatItem
struct StatItem: View {
    let icon: String
    let value: Int
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(formattedValue)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
    
    private var formattedValue: String {
        if value >= 1000 {
            return String(format: "%.1fk", Double(value) / 1000)
        }
        return "\(value)"
    }
}
