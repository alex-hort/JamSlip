//
//  NotiJamsAudiusCardView.swift
//  Splash Screen
//
//  Created by Alexis Horteales Espinosa on 31/01/26.
//

import SwiftUI

struct NotiJamsAudiusCardView: View {
    let track: AudiusTrack
    let width: CGFloat
    let height: CGFloat
    let isPlaying: Bool
    let isLiked: Bool
    let isSaved: Bool
    let isReposted: Bool
    let likesCount: Int
    let repostsCount: Int
    
    let onPlayTap: () -> Void
    let onLikeTap: () -> Void
    let onRepostTap: () -> Void
    let onSaveTap: () -> Void
    
    private let cornerRadius: CGFloat = 24
    
    var body: some View {
        VStack(spacing: 0) {
            // Artwork - tap para play/pause
            ZStack {
                Button(action: onPlayTap) {
                    Group {
                        if let imageURL = track.imageURL, let url = URL(string: imageURL) {
                            CachedAsyncImage(url: url) { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                            } placeholder: {
                                NotiJamsPlaceholder()
                            }
                            .frame(width: width, height: height - 100)
                            .clipped()
                        } else {
                            NotiJamsPlaceholder()
                                .frame(width: width, height: height - 100)
                        }
                    }
                }
                .buttonStyle(.plain)
                
                // Gradient
                LinearGradient(
                    colors: [.clear, .black.opacity(0.5)],
                    startPoint: .center,
                    endPoint: .bottom
                )
            }
            .clipShape(
                UnevenRoundedRectangle(
                    topLeadingRadius: cornerRadius,
                    topTrailingRadius: cornerRadius
                )
            )
            
            // Info section
            VStack(spacing: 10) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(track.title)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        Text("@\(track.user.handle)")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    
                    Spacer()
                    
                    // Duration
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 10))
                        Text(formatDuration(track.duration))
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(.gray)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Capsule())
                }
                
                // Action buttons
                HStack(spacing: 0) {
                    NotiJamsActionButton(
                        icon: isLiked ? "heart.fill" : "heart",
                        count: likesCount,
                        color: isLiked ? .red : .white,
                        action: onLikeTap
                    )
                    
                    Spacer()
                    
                    NotiJamsActionButton(
                        icon: "arrow.2.squarepath",
                        count: repostsCount,
                        color: isReposted ? .green : .white,
                        action: onRepostTap
                    )
                    
                    Spacer()
                    
                    NotiJamsActionButton(
                        icon: isSaved ? "bookmark.fill" : "bookmark",
                        count: 0,
                        color: isSaved ? .yellow : .white,
                        showCount: false,
                        action: onSaveTap
                    )
                }
            }
            .padding(14)
            .background(Color.white.opacity(0.08))
            .clipShape(
                UnevenRoundedRectangle(
                    bottomLeadingRadius: cornerRadius,
                    bottomTrailingRadius: cornerRadius
                )
            )
        }
        .frame(width: width, height: height)
    }
    
    private func formatDuration(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
