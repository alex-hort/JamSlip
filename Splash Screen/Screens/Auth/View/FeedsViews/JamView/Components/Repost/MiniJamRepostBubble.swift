//
//  MiniJamRepostBubble.swift
//  Splash Screen
//
//  Created by Alexis Horteales Espinosa on 28/01/26.
//

import SwiftUI
// MARK: - Mini Jam Repost Bubble
struct MiniJamRepostBubble: View {
    let repost: VisibleJamRepost
    
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color.white.opacity(0.3))
                .frame(width: 20, height: 20)
                .overlay {
                    if let url = repost.profileUrl, !url.isEmpty {
                        AsyncImage(url: URL(string: url)) { img in
                            img.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Image(systemName: "person.fill")
                                .font(.system(size: 8))
                                .foregroundColor(.white)
                        }
                        .clipShape(Circle())
                    } else {
                        Image(systemName: "person.fill")
                            .font(.system(size: 8))
                            .foregroundColor(.white)
                    }
                }
            
            Text("@\(repost.username)")
                .font(.system(size: 10, weight: .semibold))
                .lineLimit(1)
            
            Text(repost.timeAgo)
                .font(.system(size: 8))
                .opacity(0.7)
        }
        .foregroundColor(textColor(for: repost.color))
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(repost.color)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
    }
    
    private func textColor(for bgColor: Color) -> Color {
        if bgColor == .yellow || bgColor == .mint || bgColor == .cyan {
            return .black
        }
        return .white
    }
}
