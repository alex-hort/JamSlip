//
//  SideControlsView.swift
//  Splash Screen
//
//  Created by Alexis Horteales Espinosa on 17/01/26.
//
import SwiftUI

struct SideControlsView: View {
    let track: AudiusTrack
    @Binding var showLikeAnim: Bool
    @Binding var showSaveAnim: Bool
    @Binding var showRepostAnim: Bool
    let onLike: () -> Void
    let onSave: () -> Void
    let onRepost: () -> Void
    
    @ObservedObject private var userJamsService = UserJamsService.shared
    @ObservedObject private var repostService = RepostService.shared
    
    // Estado local para forzar actualización
    @State private var repostCount: Int = 0
    
    var body: some View {
        VStack(spacing: 16) {
            SideActionButton(
                icon: userJamsService.isLiked(track) ? "heart.fill" : "heart",
                count: userJamsService.getLikesCount(for: track.id),
                isActive: userJamsService.isLiked(track),
                activeColor: .red,
                showAnim: showLikeAnim,
                action: onLike
            )
            
            SideActionButton(
                icon: userJamsService.isSaved(track) ? "bookmark.fill" : "bookmark",
                count: userJamsService.getSavesCount(for: track.id),
                isActive: userJamsService.isSaved(track),
                activeColor: .yellow,
                showAnim: showSaveAnim,
                action: onSave
            )
            
            SideActionButton(
                icon: "arrow.2.squarepath",
                count: repostCount,
                isActive: repostService.isReposted(track.id),
                activeColor: .green,
                showAnim: showRepostAnim,
                action: {
                    onRepost()
                    // Actualizar count inmediatamente después del repost
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        repostCount = repostService.getRepostCount(for: track.id)
                    }
                }
            )
        }
        .onAppear {
            repostCount = repostService.getRepostCount(for: track.id)
        }
        .onChange(of: repostService.repostCounts) { _, newCounts in
            if let count = newCounts[track.id] {
                repostCount = count
            }
        }
        .onChange(of: repostService.myRepostedTrackIds) { _, _ in
            // Cuando cambia mis reposts, actualizar count
            repostCount = repostService.getRepostCount(for: track.id)
        }
    }
}

