//
//  HomeView.swift
//  Splash Screen
//
//  Created by Alexis Horteales Espinosa on 05/01/26.
//
import SwiftUI

enum HomeSection: String, CaseIterable {
    case following = "Following"
    case randjams = "RandJams"
    case jams = "Jams"
}

struct HomeView: View {
    
    @EnvironmentObject var authVM: AuthViewModel
    @StateObject private var jamsService = MyJamsService.shared
    @ObservedObject private var storeKit = StoreKitManager.shared // ✅ Observar estado premium
    
    @State private var selectedSection: HomeSection = .randjams
    @Namespace private var tabAnimation
    @State private var jamsRandViewId = UUID()
    @State private var followingViewId = UUID()
    @State private var showUploadSheet = false
    @State private var showPaywallForUpload = false
    
    var body: some View {
        VStack(spacing: 0) {
            header
            tabs
            content
        }
        .background(Color.black)
        .onAppear {
            jamsService.startFeedListener()
        }
        .onDisappear {
            jamsService.stopFeedListener()
        }
        .onChange(of: selectedSection) { oldValue, newValue in
            AudioPlayerManager.shared.pause()
        }
        .sheet(isPresented: $showUploadSheet) {
            UploadJamsView()
        }
        .sheet(isPresented: $showPaywallForUpload) {
            PaywallView()
        }
    }
    
    private var header: some View {
        ZStack {
            HStack(spacing: 8) {
                Image(.logo)
                    .resizable()
                    .frame(width: 40, height: 40)
                
                Text("JamSlip.")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            
            HStack {
                Spacer()
                
                if selectedSection == .jams {
                    ZStack(alignment: .bottomTrailing) {
                        uploadButton
                            .transition(.scale.combined(with: .opacity))
                        
                        // ✅ Indicador de verificación
                        if !storeKit.isVerified {
                            verificationBadge
                                .offset(x: 4, y: 4)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, UIApplication.shared.windows.first?.safeAreaInsets.top ?? 16)
        .padding(.bottom, 10)
        .background(Color.black)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedSection)
    }
    
    // ✅ NUEVO: Badge de verificación
    private var verificationBadge: some View {
        Circle()
            .fill(Color.orange)
            .frame(width: 12, height: 12)
            .overlay(
                ProgressView()
                    .scaleEffect(0.4)
                    .tint(.white)
            )
    }
    
    // ✅ Botón de upload con lógica de premium
    private var uploadButton: some View {
        Button(action: handleUploadTap) {
            ZStack {
                Circle()
                    .fill(uploadButtonColor)
                    .frame(width: 36, height: 36)
                    .shadow(
                        color: uploadButtonShadowColor,
                        radius: storeKit.isSubscribed ? 8 : 4,
                        y: 2
                    )
                
                if storeKit.isVerified {
                    if storeKit.isSubscribed {
                        // Usuario premium - icono normal
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.black)
                    } else {
                        // Usuario free - candado
                        Image(systemName: "lock.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                } else {
                    // Verificando - spinner
                    ProgressView()
                        .scaleEffect(0.7)
                        .tint(.white)
                }
            }
        }
        .disabled(!storeKit.isVerified) // ✅ Deshabilitado hasta verificar
    }
    
    // ✅ Color del botón según estado
    private var uploadButtonColor: Color {
        if !storeKit.isVerified {
            return Color.gray.opacity(0.3)
        }
        return storeKit.isSubscribed ? Color.white : Color.gray.opacity(0.5)
    }
    
    // ✅ Sombra del botón
    private var uploadButtonShadowColor: Color {
        if !storeKit.isVerified {
            return .clear
        }
        return storeKit.isSubscribed ? Color.white.opacity(0.3) : .clear
    }
    
    // ✅ Lógica para manejar tap en upload
    private func handleUploadTap() {
        // ✅ CRÍTICO: No hacer nada si no está verificado
        guard storeKit.isVerified else {
            print("⏳ Esperando verificación de suscripción...")
            return
        }
        
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        
        if storeKit.isSubscribed {
            // Usuario premium - abrir sheet de upload
            showUploadSheet = true
        } else {
            // Usuario free - mostrar paywall
            showPaywallForUpload = true
        }
    }
    
    private var tabs: some View {
        HStack(spacing: 28) {
            ForEach(HomeSection.allCases, id: \.self) { section in
                tabItem(section)
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 10)
        .background(Color.black)
    }
    
    private func tabItem(_ section: HomeSection) -> some View {
        VStack(spacing: 5) {
            Text(section.rawValue)
                .font(.system(size: 15, weight: selectedSection == section ? .semibold : .regular))
                .foregroundStyle(selectedSection == section ? .white : .gray)
                .onTapGesture {
                    handleTabTap(section)
                }
            
            if selectedSection == section {
                Capsule()
                    .fill(Color.white)
                    .frame(width: 22, height: 3)
                    .matchedGeometryEffect(id: "tab_indicator", in: tabAnimation)
            } else {
                Capsule()
                    .fill(Color.clear)
                    .frame(width: 22, height: 3)
            }
        }
    }
    
    private func handleTabTap(_ section: HomeSection) {
        if section == selectedSection {
            // Double tap para refrescar
            if section == .randjams {
                refreshRandJams()
            } else if section == .following {
                refreshFollowing()
            }
        } else {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                selectedSection = section
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }
    
    private func refreshRandJams() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        AudioPlayerManager.shared.stop()
        jamsRandViewId = UUID()
    }
    
    private func refreshFollowing() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        AudioPlayerManager.shared.stop()
        followingViewId = UUID()
    }
    
    private var content: some View {
        ZStack {
            // Following Feed
            FollowingFeedView(isSelected: selectedSection == .following)
                .id(followingViewId)
                .opacity(selectedSection == .following ? 1 : 0)
                .allowsHitTesting(selectedSection == .following)
            
            // RandJams Feed
            JamsRandView()
                .id(jamsRandViewId)
                .opacity(selectedSection == .randjams ? 1 : 0)
                .allowsHitTesting(selectedSection == .randjams)
            
            // Premium Jams Feed
            JamViews(isSelected: selectedSection == .jams)
                .opacity(selectedSection == .jams ? 1 : 0)
                .allowsHitTesting(selectedSection == .jams)
        }
    }
}
