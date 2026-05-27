//
//  TagView.swift
//  Splash Screen
//
//  Created by Alexis Horteales Espinosa on 22/01/26.
//

import SwiftUI
// MARK: - TagView
struct TagView: View {
    let text: String
    
    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .stroke(Color.secondary.opacity(0.4))
            )
    }
}
