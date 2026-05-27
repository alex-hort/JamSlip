//
//  FeedEmptyStateCard.swift
//  Splash Screen
//
//  Created by Alexis Horteales Espinosa on 17/02/26.
//
import SwiftUI

struct FeedEmptyStateCard: View {
    
    @State private var shimmer = false
    
    var body: some View {
        ZStack {
            
            // MARK: - Card Background
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.25),
                        radius: 12,
                        x: 0,
                        y: 8)
            
            VStack(spacing: 18) {
                
                // MARK: - Banner Skeleton
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 240)
                    .overlay {
                        VStack(spacing: 10) {
                            
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 32, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.65))
                            
                            Text("Tap to reload feed")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.white.opacity(0.65))
                        }
                    }
                
                // MARK: - Text Skeleton
                VStack(alignment: .leading, spacing: 12) {
                    
                    SkeletonLine(width: 190, height: 14)
                    SkeletonLine(width: 130, height: 12, opacity: 0.6)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
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



// MARK: - Shimmer Effect
extension FeedEmptyStateCard {
    
    var shimmerLayer: some View {
        GeometryReader { geo in
            LinearGradient(
                colors: [
                    .clear,
                    Color.white.opacity(0.25),
                    .clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .rotationEffect(.degrees(18))
            .offset(x: shimmer ? geo.size.width * 1.5 : -geo.size.width * 1.5)
            .animation(
                .linear(duration: 1.6)
                .repeatForever(autoreverses: false),
                value: shimmer
            )
        }
    }
}
