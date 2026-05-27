//
//  JamPremiumView.swift
//  Splash Screen
//
//  Created by Alexis Horteales Espinosa on 22/01/26.
//
import SwiftUI

struct JamPremiumView: View {
    
    // Si es nil, muestra los jams del usuario actual
    // Si tiene valor, muestra los jams de ese usuario
    var userId: String? = nil
    
    @ObservedObject var myJamsService = MyJamsService.shared
    @ObservedObject private var storeKit = StoreKitManager.shared
    
    @State private var otherUserJams: [Jam] = []
    @State private var isLoadingOtherUser = false
    @State private var showPaywall = false
    
    // Determinar qué jams mostrar
    private var jamsToShow: [Jam] {
        if userId != nil {
            return otherUserJams
        } else {
            return myJamsService.myJams
        }
    }
    
    private var isLoading: Bool {
        if userId != nil {
            return isLoadingOtherUser
        } else {
            return myJamsService.isLoading
        }
    }
    
    // Verificar si es el perfil propio
    private var isOwnProfile: Bool {
        userId == nil
    }
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if jamsToShow.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 18) {
                        ForEach(jamsToShow) { jam in
                            JamPremiumCellView(jam: jam, showDeleteOption: isOwnProfile)
                        }
                    }
                    .padding(.vertical, 12)
                }
                .scrollIndicators(.hidden)
            }
        }
        .task {
            await loadJams()
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
    }
    
    private func loadJams() async {
        if let userId = userId {
            // Cargar jams de otro usuario
            isLoadingOtherUser = true
            otherUserJams = await MyJamsService.shared.fetchJams(for: userId)
            isLoadingOtherUser = false
        } else {
            // Cargar mis jams
            await myJamsService.fetchMyJams()
        }
    }
    
    // MARK: - Empty State
    @ViewBuilder
    private var emptyState: some View {
        if isOwnProfile && !storeKit.isSubscribed {
            // Usuario nuevo SIN premium - Mostrar CTA de premium
            premiumCallToAction
        } else {
            // Usuario premium o perfil de otro usuario - Mensaje normal
            normalEmptyState
        }
    }
    
    
    // MARK: - Premium CTA (Free users without jams)
    
    private var premiumCallToAction: some View {
        VStack(spacing: 28) {
            
            Spacer()
            
            // Logo
            Image(.logoP)
                .resizable()
                .scaledToFit()
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .white.opacity(0.06), radius: 8, y: 4)
            
            // Text
            VStack(spacing: 6) {
                
                Text("Try 3 days free")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
                
                Text("Unlock unlimited access with Premium.")
                    .font(.system(size: 14))
                    .foregroundColor(.gray.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            // Button
            Button {
                showPaywall = true
            } label: {
                Text("Start Free Trial")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 28)
                            .fill(Color.white)
                    )
            }
            .padding(.horizontal, 50)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    
    
    // MARK: - Normal Empty State
    private var normalEmptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "waveform.badge.plus")
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            
            Text(isOwnProfile ? "You don't have any Jams yet" : "No Jams yet")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text(
                isOwnProfile
                ? "Upload your first jam and share it with the world"
                : "This user hasn't uploaded any Jams yet"
            )
            .font(.subheadline)
            .foregroundColor(.secondary.opacity(0.7))
            .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

