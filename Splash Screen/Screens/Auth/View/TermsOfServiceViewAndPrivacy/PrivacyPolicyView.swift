//
//  PrivacyPolicyView.swift
//  Splash Screen
//
//  Created by Alexis Horteales Espinosa on 07/02/26.
//

import SwiftUI

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        
                        header
                        
                        policyCard(
                            title: "1. Introduction",
                            text: """
                            JamSlip respects your privacy and is committed to protecting your personal information.
                            
                            This Privacy Policy explains what data we collect, how we use it, and your rights.
                            """
                        )
                        
                        policyCard(
                            title: "2. Information We Collect",
                            text: """
                            Account Information:
                            • Full name
                            • Username
                            • Email address
                            • Encrypted password
                            • Profile image
                            • Banner image
                            • Account creation date
                            
                            Usage Data:
                            • Likes
                            • Reposts
                            • Saved content
                            • Follow relationships
                            • Subscription status
                            • Interaction with feeds
                            
                            Authentication Data:
                            If signing in with Apple or Google, we receive basic account information necessary for authentication.
                            
                            Notifications:
                            If enabled, we may send push notifications.
                            
                            Subscription Validation:
                            We validate subscription status through Apple. We do not collect or store payment or banking data.
                            """
                        )
                        
                        policyCard(
                            title: "3. How We Use Your Information",
                            text: """
                            We use collected data to:
                            • Create and manage accounts
                            • Provide music recommendations
                            • Enable social features (likes, reposts, follows)
                            • Display subscription status
                            • Improve user experience
                            • Send notifications (if enabled)
                            • Ensure security and prevent abuse
                            """
                        )
                        
                        policyCard(
                            title: "4. Data Storage & Security",
                            text: """
                            We implement appropriate technical and organizational measures to protect user data.
                            
                            Passwords are stored securely and are not publicly accessible.
                            """
                        )
                        
                        policyCard(
                            title: "5. Account Deletion & Data Removal",
                            text: """
                            Users may delete their account at any time.
                            
                            Upon deletion:
                            • All associated data is permanently removed
                            • Data cannot be recovered
                            """
                        )
                        
                        policyCard(
                            title: "6. Third-Party Content",
                            text: """
                            JamSlip may display audio content from publicly available music sources.
                            
                            We are not responsible for the privacy practices of external platforms.
                            """
                        )
                        
                        policyCard(
                            title: "7. Children's Privacy",
                            text: """
                            JamSlip is not intended for children under 13 years of age.
                            """
                        )
                        
                        policyCard(
                            title: "8. Your Rights",
                            text: """
                            Depending on your jurisdiction, you may have the right to:
                            • Access your data
                            • Request correction
                            • Request deletion
                            
                            You may exercise these rights by contacting support.
                            """
                        )
                        
                        policyCard(
                            title: "9. Changes to This Policy",
                            text: """
                            We may update this Privacy Policy periodically. Continued use of the App indicates acceptance of updates.
                            """
                        )
                        
                        policyCard(
                            title: "10. Contact Information",
                            text: """
                            If you have any questions about this Privacy Policy, your personal data, or your rights, you may contact us at:
                            
                            Email: jamslip@gmail.com
                            
                            We will respond within a reasonable timeframe.
                            """
                        )
                        
                        Text("Last Updated: February 2026")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .padding(.top, 8)
                        
                        Spacer(minLength: 40)
                    }
                    .padding()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 32, height: 32)
                            .background(Color.white.opacity(0.15))
                            .clipShape(Circle())
                    }
                }
            }
        }
    }
    
    // MARK: - Components
    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {

            Text("Privacy Policy")
                .font(.system(size: 26, weight: .bold))
                .foregroundColor(.white)

            Text("Last Updated · February 2026")
                .font(.system(size: 13))
                .foregroundColor(.gray)
        }
        .padding(.top, 12)
        .padding(.bottom, 6)
    }

    
    private func policyCard(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 14) {

            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)

            Text(text)
                .font(.system(size: 14, weight: .regular)) // 👈 más elegante
                .foregroundColor(Color.white.opacity(0.7))
                .lineSpacing(6)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18) // 👈 padding uniforme
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.045)) // 👈 más uniforme
        )
    }

}
