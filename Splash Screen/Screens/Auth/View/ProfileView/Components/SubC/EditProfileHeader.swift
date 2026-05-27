//
//  EditProfileHeader.swift
//  Splash Screen
//
//  Created by Alexis Horteales Espinosa on 31/01/26.
//

import SwiftUI

struct EditProfileHeader: View {
    let user: User
    @Binding var tempProfileImage: UIImage?
    @Binding var tempBannerImage: UIImage?
    @Binding var removeProfileImage: Bool
    @Binding var removeBannerImage: Bool
    @Binding var showProfileActionSheet: Bool
    @Binding var showBannerActionSheet: Bool
    
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Banner
            Group {
                if let tempBanner = tempBannerImage {
                    Image(uiImage: tempBanner)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else if !removeBannerImage, let bannerUrl = user.bannerImageUrl, !bannerUrl.isEmpty {
                    CachedAsyncImage(url: URL(string: bannerUrl)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                    }
                } else {
                    Rectangle()
                        .fill(LinearGradient(
                            colors: [.purple.opacity(0.5), .blue.opacity(0.5)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                }
            }
            .frame(height: 150)
            .frame(maxWidth: .infinity)
            .clipped()
            .contentShape(Rectangle())
            .onTapGesture {
                showBannerActionSheet = true
            }
            
            // Foto de perfil
            Button {
                showProfileActionSheet = true
            } label: {
                ZStack {
                    Group {
                        if let tempProfile = tempProfileImage {
                            Image(uiImage: tempProfile)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } else if !removeProfileImage, let profileUrl = user.profileImageUrl, !profileUrl.isEmpty {
                            CachedAsyncImage(url: URL(string: profileUrl)) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Circle()
                                    .fill(Color.gray.opacity(0.3))
                            }
                        } else {
                            Circle()
                                .fill(LinearGradient(
                                    colors: [.purple.opacity(0.5), .blue.opacity(0.5)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ))
                                .overlay {
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 30))
                                        .foregroundColor(.white.opacity(0.7))
                                }
                        }
                    }
                    .frame(width: 80, height: 80)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.black, lineWidth: 4))
                    
                    // Ícono de cámara overlay
                    Circle()
                        .fill(Color.black.opacity(0.5))
                        .frame(width: 80, height: 80)
                        .overlay {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                        }
                }
            }
            .offset(x: 16, y: 40)
        }
    }
}
