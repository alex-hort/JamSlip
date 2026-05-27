//
//  FeedSkeletonCard.swift
//  Splash Screen
//
//  Created by Alexis Horteales Espinosa on 17/02/26.
//
import SwiftUI

struct FeedSkeletonCard: View {
    
    @State private var shimmer = false
    
    var body: some View {
        ZStack {
            
            // MARK: - Background Card
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(Color.white.opacity(0.05), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.25),
                        radius: 10,
                        x: 0,
                        y: 6)
            
            VStack(alignment: .leading, spacing: 18) {
                
                // MARK: Image Placeholder
                SkeletonBlock(height: 240, cornerRadius: 16)
                
                // MARK: Text Placeholders
                VStack(alignment: .leading, spacing: 12) {
                    SkeletonLine(width: 190, height: 14)
                    SkeletonLine(width: 130, height: 12, opacity: 0.6)
                }
            }
            .padding(18)
        }
        .overlay(shimmerLayer)
        .mask(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .padding(.horizontal)
        .onAppear {
            shimmer = true
        }
    }
}

//
// MARK: - Reusable Components
//

struct SkeletonBlock: View {
    var height: CGFloat
    var cornerRadius: CGFloat
    
    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color.white.opacity(0.08))
            .frame(height: height)
    }
}

struct SkeletonLine: View {
    var width: CGFloat
    var height: CGFloat
    var opacity: Double = 1
    
    var body: some View {
        RoundedRectangle(cornerRadius: height / 2, style: .continuous)
            .fill(Color.white.opacity(0.10 * opacity))
            .frame(width: width, height: height)
    }
}

//
// MARK: - Shimmer Effect
//

extension FeedSkeletonCard {
    
    var shimmerLayer: some View {
        GeometryReader { geo in
            LinearGradient(
                colors: [
                    .clear,
                    Color.white.opacity(0.22),
                    .clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .rotationEffect(.degrees(18))
            .offset(x: shimmer ? geo.size.width * 1.6 : -geo.size.width * 1.6)
            .animation(
                .linear(duration: 1.5)
                .repeatForever(autoreverses: false),
                value: shimmer
            )
        }
    }
}
