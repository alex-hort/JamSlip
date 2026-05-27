//
//  PaywallView.swift
//  Splash Screen
//
//  Created by Alexis Horteales Espinosa on 06/02/26.
//

import SwiftUI

// MARK: - Paywall View (Option B Style)
struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = SubscriptionViewModel()
    
    @State private var selectedPlan: PlanType = .yearly
    
    @State private var showTerms = false    // ✅ aquí
    @State private var showPrivacy = false  // ✅ aquí
    
    
    var body: some View {
        ZStack {
            // Background gradient
            backgroundGradient
            
            VStack(spacing: 0) {
                // Header con close button
                headerView
                    .padding(.top, 16)
                
                Spacer()
                
                // Logo
                logoSection
                
                // Title
                titleSection
                    .padding(.top, 24)
                
                // Features list
                featuresSection
                    .padding(.top, 32)
                
                Spacer()
                
                // Plan selection
                planSelectionSection
                    .padding(.top, 24)
                
                // Subscribe button
                subscribeButton
                    .padding(.top, 24)
                
                // Footer info
                footerSection
                    .padding(.top, 12)
                    .padding(.bottom, 32)
            }
            .padding(.horizontal, 24)
            
            // Success overlay
            if viewModel.showSuccessAnimation {
                successOverlay
            }
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
    
    // MARK: - Background
    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color.black,
                Color(white: 0.08)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
    
    
    // MARK: - Header
    private var headerView: some View {
        HStack {
            Spacer()
            
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(0.08))
                    )
            }
        }
    }
    
    
    
    // MARK: - Logo
    private var logoSection: some View {
        ZStack {
            
            Image("logoP")
                .resizable()
                .scaledToFit()
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    
    
    // MARK: - Title
    private var titleSection: some View {
        VStack(spacing: 6) {
            Text("Your Special Offer")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            
            Text("Unlock the full potential of JamSlip")
                .fontWeight(.medium)
                .foregroundColor(.white.opacity(0.6))
        }
    }
    
    
    // MARK: - Features
    private var featuresSection: some View {
        VStack(spacing: 0) {
            ForEach(PremiumFeature.allCases, id: \.self) { feature in
                FeatureRow(feature: feature)
                
                if feature != PremiumFeature.allCases.last {
                    Divider()
                        .background(Color.white.opacity(0.08))
                }
            }
        }
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white.opacity(0.04))
        )
    }
    
    
    // MARK: - Plan Selection
    private var planSelectionSection: some View {
        HStack(spacing: 12) {
            // Yearly Plan
            PlanCard(
                plan: .yearly,
                isSelected: selectedPlan == .yearly,
                trialDays: viewModel.hasTrialAvailable ? 3 : nil
            ) {
                withAnimation(.spring(response: 0.3)) {
                    selectedPlan = .yearly
                }
            }
            
            // Monthly Plan
            PlanCard(
                plan: .monthly,
                isSelected: selectedPlan == .monthly,
                trialDays: viewModel.hasTrialAvailable ? 3 : nil
            ) {
                withAnimation(.spring(response: 0.3)) {
                    selectedPlan = .monthly
                }
            }
        }
    }
    
    // MARK: - Subscribe Button
    private var subscribeButton: some View {
        Button {
            Task { await viewModel.purchase(plan: selectedPlan) }
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.3), radius: 10, y: 6)
                
                if viewModel.isPurchasing {
                    ProgressView()
                        .tint(.black)
                } else {
                    VStack(spacing: 2) {
                        if viewModel.hasTrialAvailable {
                            Text("Start Free Trial")
                                .font(.headline)
                                .foregroundColor(.black)
                            
                            Text("Then \(selectedPlan.pricePerMonth)/month")
                                .font(.caption)
                                .foregroundColor(.black.opacity(0.6))
                        } else {
                            Text("Subscribe for \(selectedPlan.pricePerMonth)/month")
                                .font(.headline)
                                .foregroundColor(.black)
                        }
                    }
                }
            }
            .frame(height: 56)
        }
    }
    
    
    // MARK: - Footer
    private var footerSection: some View {
        
        VStack(spacing: 8) {
            if selectedPlan == .yearly {
                Text("One-time payment of $1,000 for 12 months")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
            }
            
            // Restore & Terms
            HStack(spacing: 16) {
                Button {
                    Task {
                        await viewModel.restorePurchases()
                    }
                } label: {
                    Text("Restore Purchases")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                }
                
                Text("•")
                    .foregroundColor(.white.opacity(0.3))
                
                Button {
                    showTerms = true
                } label: {
                    Text("Terms")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                }
                .sheet(isPresented: $showTerms) {
                    TermsOfServiceView()
                }
                
                Text("•")
                    .foregroundColor(.white.opacity(0.3))
                
                Button {
                    showPrivacy = true
                } label: {
                    Text("Privacy")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                }
                .sheet(isPresented: $showPrivacy) {
                    PrivacyPolicyView()
                }
            }
        }
    }
    
    // MARK: - Success Overlay
    private var successOverlay: some View {
        ZStack {
            // Fondo elegante tipo Apple
            LinearGradient(
                colors: [
                    Color.black.opacity(0.95),
                    Color.black.opacity(0.85)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 28) {
                
                // Premium Check Badge
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 96, height: 96)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.15), lineWidth: 1)
                        )
                    
                    Image(systemName: "checkmark")
                        .font(.system(size: 44, weight: .semibold))
                        .foregroundColor(.white)
                }
                .scaleEffect(viewModel.showSuccessAnimation ? 1 : 0.6)
                .opacity(viewModel.showSuccessAnimation ? 1 : 0)
                .animation(
                    .spring(response: 0.6, dampingFraction: 0.7),
                    value: viewModel.showSuccessAnimation
                )
                
                VStack(spacing: 10) {
                    Text("Welcome to Premium")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(.white)
                    
                    if viewModel.subscriptionInfo.isInTrialPeriod {
                        Text("Your 3-day free trial has started")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.65))
                    } else {
                        Text("You now have full access to all features")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.65))
                    }
                }
                .multilineTextAlignment(.center)
                
                Button {
                    viewModel.dismissSuccess()
                    dismiss()
                } label: {
                    Text("Comenzar")
                        .font(.headline)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 18)
                                .fill(Color.white)
                        )
                }
                .padding(.horizontal, 40)
                .padding(.top, 8)
            }
        }
        .transition(.opacity)
    }
    

// MARK: - Feature Row
struct FeatureRow: View {
    let feature: PremiumFeature
    
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: feature.icon)
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.8))
                .frame(width: 28)

            Text(feature.title)
                .font(.subheadline)
                .foregroundColor(.white)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}


// MARK: - Plan Card
struct PlanCard: View {
    let plan: PlanType
    let isSelected: Bool
    let trialDays: Int?
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                // Plan name with checkmark
                HStack {
                    Text(plan.displayName)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    }

                }
                
                // Price
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(plan.pricePerMonth)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("/month")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Trial info
                if let days = trialDays {
                    Text("\(days) days free")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(isSelected ? Color.white.opacity(0.12) : Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(
                                isSelected ? Color.white.opacity(0.35) : Color.white.opacity(0.08),
                                lineWidth: 1
                            )
                    )
            )

        }
        .buttonStyle(PlainButtonStyle())
    }
}


}
