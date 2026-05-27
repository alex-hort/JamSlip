//
//  UserAvatarView.swift
//  Splash Screen
//
//  Created by Alexis Horteales Espinosa on 14/01/26.
//
import SwiftUI

struct UserAvatarView: View {
    let user: User
    let size: CGFloat
    
    var body: some View {
        Group {
            if let profileUrl = user.profileImageUrl, !profileUrl.isEmpty {
                AsyncImage(url: URL(string: profileUrl)) { phase in
                    switch phase {
                    case .empty:
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .overlay {
                                ProgressView()
                                    .tint(.white)
                                    .scaleEffect(0.5)
                            }
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure:
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .overlay {
                                Image(systemName: "person.fill")
                                    .foregroundColor(.white.opacity(0.5))
                            }
                    @unknown default:
                        EmptyView()
                    }
                }
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .overlay {
                        Image(systemName: "person.fill")
                            .foregroundColor(.white.opacity(0.5))
                            .font(.system(size: size * 0.4))
                    }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}
