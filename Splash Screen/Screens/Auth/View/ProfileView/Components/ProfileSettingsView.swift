//
//  ProfileSettingsView.swift
//  Splash Screen
//
//  Created by Alexis Horteales Espinosa on 10/02/26.
//

import SwiftUI
import StoreKit

// MARK: - Profile Settings View
struct ProfileSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var storeKit = StoreKitManager.shared
    @EnvironmentObject var authVM: AuthViewModel
    
    @State private var showPremiumSettings = false
    @State private var showPaywall = false // ✅ NUEVO
    @State private var showLogoutConfirmation = false
    
    // ✅ NUEVO: Estados para vistas de General
    @State private var showNotifications = false
    @State private var showPrivacy = false
    @State private var showAbout = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [
                        Color.black,
                        Color.black.opacity(0.96),
                        Color(hex: "0E0E11")
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        premiumSection
                        otherOptionsSection
                        logoutSection
                        Spacer(minLength: 40)
                    }
                    .padding()
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                }
            }
        }
        .sheet(isPresented: $showPremiumSettings) {
            PremiumManagementView(showPaywall: $showPaywall) // ✅ PASAR BINDING
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView() // ✅ NUEVO: Mostrar Paywall
        }
        // ✅ NUEVO: Sheets para vistas de General
        .sheet(isPresented: $showNotifications) {
            NotificationsSettingsView()
        }
        .sheet(isPresented: $showPrivacy) {
            PrivacySettingsView()
        }
        .sheet(isPresented: $showAbout) {
            LegalView()
        }
        .alert("Log Out", isPresented: $showLogoutConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Log Out", role: .destructive) {
                authVM.signOut()
                dismiss()
            }
        } message: {
            Text("Are you sure you want to log out?")
        }
    }
    
    // MARK: - Premium Section
    private var premiumSection: some View {
        VStack(spacing: 14) {
            sectionHeader("Subscription")
            
            Button {
                showPremiumSettings = true
            } label: {
                HStack(spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(
                                storeKit.isSubscribed
                                ? Color.black
                                : Color.gray.opacity(0.3)
                            )
                            .frame(width: 56, height: 56)
                        
                        Image(.logoP)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 28, height: 28)
                            .clipShape(RoundedRectangle(cornerRadius: 7))
                    }

                    
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Text(storeKit.isSubscribed ? "Premium" : "Upgrade to Premium")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                            
                            if storeKit.isSubscribed {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(.blue)
                            }
                        }
                        
                        Text(premiumSubtitle)
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.gray)
                }
                .padding(18)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color.white.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(
                                    storeKit.isSubscribed
                                    ? Color.white.opacity(0.35)
                                    : Color.white.opacity(0.08),
                                    lineWidth: 0.5
                                )
                        )
                        .shadow(
                            color: storeKit.isSubscribed
                            ? Color.white.opacity(0.25)
                            : .black.opacity(0.5),
                            radius: 24,
                            y: 12
                        )
                )

            }
        }
    }
    
    private var premiumSubtitle: String {
        if storeKit.isSubscribed {
            storeKit.subscriptionInfo.isInTrialPeriod
            ? "Free trial active"
            : "Manage subscription"
        } else {
            "Unlock all features"
        }
    }
    
    // MARK: - Other Options
    private var otherOptionsSection: some View {
        VStack(spacing: 14) {
            sectionHeader("General")
            
            VStack(spacing: 1) {
                settingsRow(icon: "bell.fill", iconColor: .white, title: "Notifications") {
                    showNotifications = true
                }
                divider
                
                settingsRow(icon: "lock.fill", iconColor: .white, title: "Privacy") {
                    showPrivacy = true
                }
                divider
                
                settingsRow(icon: "info.circle.fill", iconColor: .white, title: "About") {
                    showAbout = true
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.25), radius: 14, x: 0, y: 8)
            )
        }
    }
    
    // MARK: - Logout Section
    private var logoutSection: some View {
        Button {
            showLogoutConfirmation = true
        } label: {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.red.opacity(0.12))
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: "arrow.right.square.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.red)
                }
                
                Text("Sign Out")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.red)
                
                Spacer()
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color.red.opacity(0.3), lineWidth: 0.5)
                    )
            )
        }
    }
    
    // MARK: - Components
    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title.uppercased())
                .font(.system(size: 13, weight: .semibold))
                .tracking(0.6)
                .foregroundColor(.gray)
            Spacer()
        }
        .padding(.horizontal, 4)
    }
    
    private var divider: some View {
        Divider()
            .background(Color.white.opacity(0.08))
            .padding(.leading, 72)
    }
    
    private func settingsRow(
        icon: String,
        iconColor: Color,
        title: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(iconColor.opacity(0.2))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: icon)
                        .font(.system(size: 18))
                        .foregroundColor(iconColor)
                }
                
                Text(title)
                    .font(.system(size: 17))
                    .foregroundColor(.white)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
    }
}


// MARK: - Premium Management View
struct PremiumManagementView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var storeKit = StoreKitManager.shared
    @StateObject private var viewModel = SubscriptionViewModel()
    
    @Binding var showPaywall: Bool // ✅ NUEVO: Recibir binding
    
    @State private var isRestoring = false
    @State private var showRestoreSuccess = false
    @State private var showRestoreError = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 32) {
                        subscriptionStatusCard
                        
                        if storeKit.isSubscribed {
                            managementOptions
                        } else {
                            upgradeSection
                        }
                        
                        restorePurchasesSection
                        
                        Spacer(minLength: 40)
                    }
                    .padding()
                }
            }
            .navigationTitle(storeKit.isSubscribed ? "Premium" : "Upgrade to Premium")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Done")
                            .foregroundColor(.white)
                            .fontWeight(.semibold)
                    }
                }
            }
        }
        .alert("Purchases Restored", isPresented: $showRestoreSuccess) {
            Button("OK") { }
        } message: {
            Text("Your premium subscription has been restored")
        }
        .alert("No Purchases Found", isPresented: $showRestoreError) {
            Button("OK") { }
        } message: {
            Text("We couldn't find any previous purchases")
        }
    }
    
    // MARK: - Subscription Status Card
    private var subscriptionStatusCard: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(
                        storeKit.isSubscribed
                        ? Color.black
                        : Color.gray.opacity(0.3)
                    )
                    .frame(width: 100, height: 100)
                
                Group {
                    if storeKit.isSubscribed {
                        Image(.logoP)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 64, height: 64)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(color: .white.opacity(0.06), radius: 8, y: 4)
                    } else {
                        Image(.logoP)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 64, height: 64)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(color: .white.opacity(0.06), radius: 8, y: 4)
                            .opacity(0.7)
                    }
                }
            }

            
            Text(storeKit.isSubscribed ? "Premium Active" : "Premium")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
            
            if storeKit.isSubscribed {
                VStack(spacing: 8) {
                    if storeKit.subscriptionInfo.isInTrialPeriod {
                        Text("Free Trial")
                            .font(.system(size: 16))
                            .foregroundColor(.gray)
                    } else {
                        Text("Active Subscription")
                            .font(.system(size: 16))
                            .foregroundColor(.gray)
                    }
                    
                    if let expirationDate = storeKit.subscriptionInfo.expirationDate {
                        Text("Renews on \(formattedDate(expirationDate))")
                            .font(.system(size: 14))
                            .foregroundColor(.gray.opacity(0.8))
                    }
                }
            } else {
                Text("Unlock all premium features")
                    .font(.system(size: 16))
                    .foregroundColor(.gray)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.white.opacity(0.05))
        )
    }
    
    // MARK: - Management Options (Para usuarios premium)
    private var managementOptions: some View {
        VStack(spacing: 16) {
            Button {
                openSubscriptionManagement()
            } label: {
                HStack(spacing: 16) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.blue)
                        )
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Manage Subscription")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Text("Change plan or cancel")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "arrow.up.forward.square.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.gray)
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.05))
                )
            }
            
            if storeKit.subscriptionInfo.willAutoRenew {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    
                    Text("Auto-renewal is ON")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
            }
        }
    }
    
    // MARK: - Upgrade Section (Para usuarios free)
    private var upgradeSection: some View {
        VStack(spacing: 16) {
            Text("Premium includes:")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 12) {
                featureRow(icon: "checkmark.seal.fill", text: "Verified Badge")
                featureRow(icon: "music.note.list", text: "Unlimited Uploads")
                featureRow(icon: "waveform", text: "Spatial Audio")
                featureRow(icon: "eye.fill", text: "Greater Visibility")
            }
            
            // ✅ BOTÓN DINÁMICO según si ya usó trial
            Button {
                dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    showPaywall = true
                }
            } label: {
                VStack(spacing: 4) {
                    Text(viewModel.hasTrialAvailable ? "Start Free Trial" : "Upgrade to Premium")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.black)

                    if !viewModel.hasTrialAvailable {
                        Text("From $99/month")
                            .font(.system(size: 13))
                            .foregroundColor(.black.opacity(0.6))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, viewModel.hasTrialAvailable ? 16 : 14)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.white)
                        .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 6)
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
        )
    }
    
    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(.white) 
                .frame(width: 24)
            
            Text(text)
                .font(.system(size: 15))
                .foregroundColor(.white)
            
            Spacer()
        }
    }
    
    // MARK: - Restore Purchases
    private var restorePurchasesSection: some View {
        Button {
            Task {
                await restorePurchases()
            }
        } label: {
            HStack(spacing: 16) {
                Image(systemName: isRestoring ? "arrow.clockwise" : "arrow.clockwise.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.green.opacity(0.2))
                    )
                    .rotationEffect(.degrees(isRestoring ? 360 : 0))
                    .animation(isRestoring ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isRestoring)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Restore Purchases")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text("Already purchased on another device?")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
                
                Spacer()
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.05))
            )
        }
        .disabled(isRestoring)
    }
    
    // MARK: - Actions
    private func openSubscriptionManagement() {
        Task {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                do {
                    try await AppStore.showManageSubscriptions(in: windowScene)
                } catch {
                    print("❌ Error abriendo gestión: \(error)")
                    openAppStoreSubscriptions()
                }
            } else {
                openAppStoreSubscriptions()
            }
        }
    }
    
    private func openAppStoreSubscriptions() {
        if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
            UIApplication.shared.open(url)
        }
    }
    
    private func restorePurchases() async {
        isRestoring = true
        
        do {
            try await storeKit.restorePurchases()
            try? await Task.sleep(nanoseconds: 500_000_000)
            
            if storeKit.isSubscribed {
                showRestoreSuccess = true
            } else {
                showRestoreError = true
            }
        } catch {
            showRestoreError = true
        }
        
        isRestoring = false
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.locale = Locale(identifier: "en_US")
        return formatter.string(from: date)
    }
}


