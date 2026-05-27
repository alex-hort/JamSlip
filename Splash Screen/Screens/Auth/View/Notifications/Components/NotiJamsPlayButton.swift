//
//  NotiJamsPlayButton.swift
//  Splash Screen
//
//  Created by Alexis Horteales Espinosa on 31/01/26.
//


import SwiftUI

// MARK: - Play Button
struct NotiJamsPlayButton: View {
    let isPlaying: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .background(
                        Circle()
                            .fill(Color.black.opacity(0.25))
                    )
                    .shadow(color: .black.opacity(0.35), radius: 10, y: 6)

                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.white)
                    .offset(x: isPlaying ? 0 : 2)
            }
            .frame(width: 68, height: 68)
        }
        .buttonStyle(.plain)
    }
}


// MARK: - Action Button
struct NotiJamsActionButton: View {
    let icon: String
    let count: Int
    let color: Color
    var showCount: Bool = true
    let action: () -> Void

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            action()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(color)

                if showCount {
                    Text(formatCount(count))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.85))
                }
            }
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func formatCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        }
        return "\(count)"
    }
}


// MARK: - Placeholder
struct NotiJamsPlaceholder: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color.purple.opacity(0.55),
                Color.blue.opacity(0.35)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay {
            Image(systemName: "music.note")
                .font(.system(size: 44, weight: .light))
                .foregroundColor(.white.opacity(0.25))
        }
    }
}


// MARK: - Header
struct NotiJamsHeader: View {
    let onClose: () -> Void

    var body: some View {
        HStack {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 34, height: 34)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }

            Spacer()

            Text("Notification")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)

            Spacer()

            Color.clear
                .frame(width: 34, height: 34)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}


// MARK: - Footer
struct NotiJamsFooter: View {
    let notification: JamNotification

    var body: some View {
        HStack(spacing: 12) {

            AsyncImage(url: URL(string: notification.fromUserProfileUrl ?? "")) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.purple, .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        Text(String(notification.fromUsername.prefix(1)).uppercased())
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    )
            }
            .frame(width: 38, height: 38)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(notificationText)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)

                Text(notification.timeAgo)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            }

            Spacer()

            Image(systemName: notificationIcon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(notificationColor)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 24)
    }

    private var notificationText: String {
        switch notification.type {
        case .like:
            return "@\(notification.fromUsername) le dio like"
        case .repost:
            return "@\(notification.fromUsername) reposteó"
        case .friendRepost:
            return "@\(notification.fromUsername) compartió"
        case .follow:
            return "@\(notification.fromUsername) te siguió"
        }
    }

    private var notificationIcon: String {
        switch notification.type {
        case .like: return "heart.fill"
        case .repost, .friendRepost: return "arrow.2.squarepath"
        case .follow: return "person.fill.badge.plus"
        }
    }

    private var notificationColor: Color {
        switch notification.type {
        case .like: return .red
        case .repost, .friendRepost: return .green
        case .follow: return .blue
        }
    }
}


// MARK: - Loading View
struct NotiJamsLoadingView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(.white)
                .scaleEffect(1.2)
            
            Text("Cargando jam...")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
    }
}

// MARK: - Error View
struct NotiJamsErrorView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "music.note.slash")
                .font(.system(size: 50))
                .foregroundColor(.gray.opacity(0.5))
            
            Text("Jam no encontrado")
                .font(.headline)
                .foregroundColor(.white)
        }
    }
}
