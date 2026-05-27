//
//  AlbumCardView.swift
//  Splash Screen
//
//  Created by Alexis Horteales Espinosa on 17/01/26.
//

import SwiftUI

struct AlbumCardView: View {
    let track: AudiusTrack
    let width: CGFloat
    let height: CGFloat
    
    var body: some View {
        let imageURL = track.imageURL ?? ""
        
        ZStack {
            CachedAsyncImage(url: URL(string: imageURL)) { img in
                img
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: width, height: height * 1.12)
                    .clipped() // FIX: Asegura que imágenes horizontales no rompan el layout
            } placeholder: {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.purple.opacity(0.85), .blue.opacity(0.65)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay {
                        Image(systemName: "music.note")
                            .font(.system(size: 90))
                            .foregroundColor(.white.opacity(0.25))
                    }
            }
            .frame(width: width, height: height * 1.12)
            .clipShape(RoundedRectangle(cornerRadius: 28))
            
            // Gradiente inferior
            VStack {
                Spacer()
                LinearGradient(
                    colors: [
                        .clear,
                        .black.opacity(0.25),
                        .black.opacity(0.6)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 160)
            }
            .frame(width: width, height: height * 1.12)
            .clipShape(RoundedRectangle(cornerRadius: 28))
        }
        .offset(y: 10)
        .shadow(color: .black.opacity(0.45), radius: 22, y: 12)
    }
}
