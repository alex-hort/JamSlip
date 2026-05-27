//
//  UserProfileSkeletonView.swift
//  Splash Screen
//
//  Created by Alexis Horteales Espinosa on 17/02/26.
//

import SwiftUI

struct UserProfileSkeletonView: View {

    @State private var shimmer = false

    var body: some View {
        VStack(spacing: 0) {

            // MARK: Banner
            ZStack(alignment: .bottomLeading) {

                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 180)

                Circle()
                    .fill(Color.white.opacity(0.12))
                    .frame(width: 90, height: 90)
                    .offset(x: 20, y: 45)
            }

            VStack(alignment: .leading, spacing: 16) {

                Spacer().frame(height: 60)

                // Username
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white.opacity(0.12))
                    .frame(width: 160, height: 18)

                // Bio lines
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 14)

                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 220, height: 14)

                // Stats row
                HStack(spacing: 30) {
                    ForEach(0..<3) { _ in
                        VStack(spacing: 8) {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.white.opacity(0.12))
                                .frame(width: 40, height: 16)

                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.white.opacity(0.08))
                                .frame(width: 60, height: 12)
                        }
                    }
                }

                // Fake grid content
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                    ForEach(0..<9) { _ in
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.08))
                            .frame(height: 110)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 12)
        }
        .overlay(
            GeometryReader { geo in
                LinearGradient(
                    colors: [.clear, Color.white.opacity(0.25), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .rotationEffect(.degrees(18))
                .offset(x: shimmer ? geo.size.width : -geo.size.width)
            }
        )
        .clipped()  // ← Reemplaza .mask(Rectangle()) por esto
        .onAppear {
            withAnimation(
                .linear(duration: 1.2)
                .repeatForever(autoreverses: false)
            ) {
                shimmer = true
            }
        }
    }
}
