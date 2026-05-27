//
//  ProfileHeaderView.swift
//  Splash Screen
//
//  Created by Alexis Horteales Espinosa on 08/01/26.
//
import SwiftUI
import FirebaseAuth

struct ProfileHeaderView: View {
    let user: User
    @Binding var offset: CGFloat
    @Binding var titleOffset: CGFloat
    var bannerImage: UIImage?
    @ObservedObject var profileVM: ProfileViewModel
    
    // ✅ Estado para mostrar menú de configuración
    @State private var showSettingsMenu = false
    
    // ✅ Verificar si es el perfil propio
    private var isOwnProfile: Bool {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            return false
        }
        return user.uid == currentUserId
    }
    
    var body: some View {
        GeometryReader { geometry in
            let minY = geometry.frame(in: .global).minY
            
            ZStack(alignment: .bottom) {
                // Banner
                Group {
                    if let tempBanner = profileVM.tempBannerImage {
                        // Mostrar banner temporal inmediatamente
                        Image(uiImage: tempBanner)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else if let bannerImage = bannerImage {
                        Image(uiImage: bannerImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else if !profileVM.shouldRemoveBanner, let bannerUrl = user.bannerImageUrl, !bannerUrl.isEmpty {
                        AsyncImage(url: URL(string: bannerUrl)) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            default:
                                Rectangle()
                                    .fill(LinearGradient(
                                        colors: [.purple.opacity(0.5), .blue.opacity(0.5)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ))
                            }
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
                .frame(width: geometry.size.width, height: minY > 0 ? 180 + minY : 180)
                .clipped()
                .overlay {
                    BlurView()
                        .opacity(blurViewOpacity())
                }
                .overlay(alignment: .topTrailing) {
                    // ✅ Botón de configuración SOLO si es perfil propio
                    if isOwnProfile {
                        settingsButton
                    }
                }
            }
            .offset(y: minY > 0 ? -minY : 0)
            .onChange(of: minY) { oldValue, newValue in
                offset = newValue
                titleOffset = newValue
            }
        }
        .sheet(isPresented: $showSettingsMenu) {
            ProfileSettingsView()
        }
    }
    
    //settings button
    private var settingsButton: some View {
        Button {
            showSettingsMenu = true
        } label: {
            ZStack {
                // Fondo blur
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 36, height: 36)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                    )

                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            }
            // ✅ Área táctil más grande sin cambiar diseño
            .padding(12)
            .contentShape(Rectangle())
            .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
        }
        // ✅ Baja el botón de forma elegante
        .padding(.top, UIApplication.shared.windows.first?.safeAreaInsets.top ?? 20 + 12)
        .padding(.trailing, 16)
    }
    
    func blurViewOpacity() -> Double {
        let progress = -(offset + 80) / 150
        return Double(-offset > 80 ? progress : 0)
    }
}



