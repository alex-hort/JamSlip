//
//  ArtistInfoView.swift
//  Splash Screen
//
//  Created by Alexis Horteales Espinosa on 17/01/26.
//

import SwiftUI

struct ArtistInfoView: View {
    let track: AudiusTrack
    
    var body: some View {
        HStack(spacing: 12) {
            ArtistAvatarView(
                profileUrl: track.user.profilePicture,
                name: track.user.name
            )
            
            VStack(alignment: .leading, spacing: 3) {
                MarqueeText(
                    text: track.title,
                    font: .system(size: 16, weight: .semibold)
                )
                .frame( height: 22)


                Text(track.user.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(1)
            }

        }
    }
}




