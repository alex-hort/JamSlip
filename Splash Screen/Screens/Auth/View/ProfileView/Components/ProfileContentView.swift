//
//  ProfileContentView.swift
//  Splash Screen
//
//  Created by Alexis Horteales Espinosa on 08/01/26.
//
import SwiftUI

enum ProfileTab: String {
    case jams = "Jams"
    case saved = "Saved"
    case liked = "Liked"
}

struct ProfileContentView: View {
    let user: User
    @ObservedObject var profileVM: ProfileViewModel
    var profileImage: UIImage?
    var onProfileUpdated: (() -> Void)? = nil
    var isOwnProfile: Bool = true
    var onUserTap: ((User) -> Void)? = nil  // ✅ Agrega esto

    @State private var selectedTab: ProfileTab = .jams
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
           
            ProfileTopSection(
                user: user,
                profileVM: profileVM,
                profileImage: profileImage,
                onProfileUpdated: onProfileUpdated
            )
            
            ProfileInfoSectionWithBadge(
                user: user,
                pendingName: profileVM.pendingFullName,
                isOwnProfile: isOwnProfile
            )
            
            let displayBio = profileVM.pendingBio ?? user.bio
            if let bio = displayBio, !bio.isEmpty {
                Text(bio)
                    .foregroundColor(.white)
                    .font(.subheadline)
                    .padding(.horizontal)
                    .offset(y: -20)
            }
            
            HStack(spacing: 4) {
                Image(systemName: "figure.wave")
                    .foregroundColor(.white.opacity(0.6))
                    .font(.subheadline)
                
                Text(user.formattedJoinDate)
                    .foregroundColor(.white.opacity(0.6))
                    .font(.subheadline)
            }
            .padding(.horizontal)
            .offset(y: displayBio != nil && !displayBio!.isEmpty ? -15 : -20)
            
            // ✅ Pasa onUserTap a ProfileStatsView
            ProfileStatsView(user: user, onUserTap: onUserTap)
            
            ProfileTabsView(selectedTab: $selectedTab)
                .padding(.top, 12)

            Divider()
                .background(Color.white.opacity(0.15))
                .padding(.horizontal)

            Group {
                switch selectedTab {
                case .jams:
                    if isOwnProfile {
                        JamPremiumView()
                    } else {
                        JamPremiumView(userId: user.uid)
                    }
                case .saved:
                    SavedJamsView(userId: user.uid)
                case .liked:
                    LikedJamsView(userId: user.uid)
                }
            }
        }
    }
}

// MARK: - Profile Info Section WITH Premium Badge
struct ProfileInfoSectionWithBadge: View {
    let user: User
    var pendingName: String?
    var isOwnProfile: Bool = true
    
    @ObservedObject private var storeKit = StoreKitManager.shared
    
    private var showPremiumBadge: Bool {
        if isOwnProfile {
            return storeKit.isSubscribed
        } else {
            return user.isPremium
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Nombre con badge
            HStack(spacing: 4) {
                Text(pendingName ?? user.fullName)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                // Premium Badge
                if showPremiumBadge {
                    PremiumVerifiedBadge()
                        .offset(y: 1)
                }
            }
            
            // Username
            Text("@\(user.username)")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .padding(.horizontal)
        .offset(y: -20)
    }
}


// MARK: - Premium Verified Badge
struct PremiumVerifiedBadge: View {
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            // Sutil background
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(hex: "4B70F5").opacity(0.25),
                            Color(hex: "4B70F5").opacity(0.0)
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 18
                    )
                )
                .frame(width: 28, height: 28)
                .scaleEffect(isAnimating ? 1.05 : 1)
                .opacity(isAnimating ? 0.4 : 0.6)

            // Badge icon
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color(hex: "7DA6FF"),
                            Color(hex: "4B70F5")
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(
                    color: .black.opacity(0.5),
                    radius: 2,
                    y: 1
                )
        }
        .onAppear {
            withAnimation(
                .easeInOut(duration: 1.8)
                .repeatForever(autoreverses: true)
            ) {
                isAnimating = true
            }
        }
    }
}

// MARK: - Premium Username View (para usar en otras partes de la app)
struct PremiumUsernameView: View {
    let username: String
    let isPremium: Bool
    var fontSize: Font = .subheadline
    
    var body: some View {
        HStack(spacing: 4) {
            Text("@\(username)")
                .font(fontSize)
                .fontWeight(.medium)
                .foregroundColor(.white)
            
            if isPremium {
                PremiumVerifiedBadge()
            }
        }
    }
}

// MARK: - Color Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)

        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255

        self.init(red: r, green: g, blue: b)
    }
}
