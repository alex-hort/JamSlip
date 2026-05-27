//
//  NotiJamsCardView.swift
//  Splash Screen
//
//  Created by Alexis Horteales Espinosa on 31/01/26.
//
import SwiftUI

struct NotiJamsCardView: View {
    let jam: Jam
    let width: CGFloat
    let height: CGFloat
    let isPlaying: Bool
    let isLiked: Bool
    let isSaved: Bool
    let isReposted: Bool
    let likesCount: Int
    let repostsCount: Int
    let savesCount: Int

    let onPlayTap: () -> Void
    let onLikeTap: () -> Void
    let onRepostTap: () -> Void
    let onSaveTap: () -> Void

    private let cornerRadius: CGFloat = 28

    var body: some View {
        VStack(spacing: 0) {

            // MARK: - Artwork
            ZStack(alignment: .bottomLeading) {
                Button(action: onPlayTap) {
                    Group {
                        if let artworkUrl = jam.artworkUrl,
                           let url = URL(string: artworkUrl) {
                            CachedAsyncImage(url: url) { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                            } placeholder: {
                                NotiJamsPlaceholder()
                            }
                        } else {
                            NotiJamsPlaceholder()
                        }
                    }
                    .frame(width: width, height: height * 0.62)
                    .clipped()
                }
                .buttonStyle(.plain)

                // Gradient overlay (más suave)
                LinearGradient(
                    colors: [
                        .clear,
                        .black.opacity(0.25),
                        .black.opacity(0.6)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                // Play indicator
                if isPlaying {
                    HStack {
                        Image(systemName: "waveform")
                            .font(.caption.bold())
                        Text("Playing")
                            .font(.caption.bold())
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .padding(14)
                }
            }
            .clipShape(
                UnevenRoundedRectangle(
                    topLeadingRadius: cornerRadius,
                    topTrailingRadius: cornerRadius
                )
            )

            // MARK: - Info Section
            VStack(spacing: 14) {

                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                    
                        MarqueeText(
                            text: jam.title,
                            font: .system(size: 18, weight: .semibold),
                            speed: 28,
                            delay: 1.5
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)

                        HStack(spacing: 6) {
                            Text(jam.formattedDate)
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.6))

                            Text("•")
                                .foregroundColor(.white.opacity(0.4))

                            Text("@\(jam.username)")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }

                    Spacer()

                    Text(jam.genre.uppercased())
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(.ultraThinMaterial)
                        )
                }

                // MARK: - Actions
                HStack {
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
                        count: savesCount,
                        color: isSaved ? .yellow : .white,
                        action: onSaveTap
                    )
                }
                .padding(.top, 4)
            }
            .padding(18)
            .background(
                .ultraThinMaterial
            )
            .clipShape(
                UnevenRoundedRectangle(
                    bottomLeadingRadius: cornerRadius,
                    bottomTrailingRadius: cornerRadius
                )
            )
        }
        .frame(width: width, height: height)
        .shadow(color: .black.opacity(0.35), radius: 20, y: 10)
    }
}

