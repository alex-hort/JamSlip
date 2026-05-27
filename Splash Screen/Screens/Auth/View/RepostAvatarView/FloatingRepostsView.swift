//
//  FloatingRepostsView.swift
//  Splash Screen
//
//  Created by Alexis Horteales Espinosa on 17/01/26.
//

import SwiftUI

struct FloatingRepostsView: View {
    let reposts: [VisibleRepost]
    let cardWidth: CGFloat
    let cardHeight: CGFloat
    
    var body: some View {
        let maxReposts = min(reposts.count, 5)
        let padding: CGFloat = 20
        let availableHeight = cardHeight - 150
        let spacing = min(availableHeight / CGFloat(max(maxReposts, 1)), 80)
        
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(reposts.prefix(maxReposts).enumerated()), id: \.element.id) { index, repost in
                MiniRepostBubble(repost: repost)
                    .frame(maxWidth: cardWidth - 40)
                    .offset(
                        x: CGFloat(index % 2 == 0 ? 0 : 30),
                        y: CGFloat(index) * spacing + padding
                    )
            }
            Spacer()
        }
        .frame(width: cardWidth, height: cardHeight, alignment: .topLeading)
        .padding(.leading, padding)
        .clipped()
    }
}

