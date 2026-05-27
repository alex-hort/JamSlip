//
//  MoodChip.swift
//  Splash Screen
//
//  Created by Alexis Horteales Espinosa on 21/01/26.
//
import SwiftUI

struct MoodChip: View {
    let mood: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Text(mood)
            .font(.footnote)
            .padding(.vertical, 8)
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(isSelected ? color : color.opacity(0.25))
            )
            .foregroundColor(.black)
            .onTapGesture { action() }
    }
}


extension Mood {
    var color: Color {
        switch self {
        case .happy: return .yellow
        case .sad: return .blue
        case .romantic: return .pink
        case .nostalgic: return .orange
        case .melancholic: return .purple

        case .energetic: return .red
        case .chill: return .mint
        case .dark: return .gray
        case .aggressive: return .brown

        case .party: return .cyan
        case .sexy: return .pink.opacity(0.9)
        case .motivational: return .green
        }
    }
}
