//
//  TermsOfServiceView.swift
//  Splash Screen
//
//  Created by Alexis Horteales Espinosa on 07/02/26.
//

import SwiftUI

struct TermsOfServiceView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Terms & Conditions")
                                .font(.system(size: 26, weight: .bold))
                                .foregroundColor(.white)

                            Text("Last Updated · February 2026")
                                .font(.system(size: 13))
                                .foregroundColor(.gray)
                        }
                        .padding(.top, 12)
                        .padding(.bottom, 6)


                        section(
                            title: "1. Acceptance of Terms",
                            text: """
                            By downloading, accessing, or using JamSlip ("the App"), you agree to be bound by these Terms and Conditions. If you do not agree, you must not use the App.
                            
                            JamSlip is currently available in English.
                            """
                        )

                        section(
                            title: "2. Description of Service",
                            text: """
                            JamSlip is a music discovery and sharing application that:
                            • Recommends random audio content from public music sources
                            • Allows Premium users to upload and share original "Jams"
                            • Allows users to like, repost, follow, and save content
                            • Displays three main feeds: RandJams (random music feed), Jams (user uploaded content), Following (content from followed users)
                            
                            Advertisements may appear within certain feeds.
                            """
                        )

                        section(
                            title: "3. Account Registration",
                            text: """
                            To use certain features, users must create an account.
                            
                            During registration, we may collect:
                            • Full name
                            • Username
                            • Email address
                            • Password
                            • Profile image
                            • Banner image
                            • Account creation date
                            
                            Users may register using:
                            • Email and password
                            • Google sign-in
                            • Apple sign-in
                            
                            If signing in via Google or Apple, a username is automatically generated and cannot be edited in version 1.0.
                            
                            Users are responsible for maintaining the confidentiality of their login credentials.
                            """
                        )

                        section(
                            title: "4. Password Reset",
                            text: """
                            Users may reset their password if:
                            • They have access to the registered email address
                            • The account is valid and active
                            """
                        )

                        section(
                            title: "5. User Content (Jams)",
                            text: """
                            Only Premium users may upload Jams.
                            
                            By uploading content, users:
                            • Confirm they own or have the necessary rights to the content
                            • Grant JamSlip a non-exclusive, worldwide, royalty-free license to display and distribute the content within the App
                            
                            Users may delete their own Jams at any time. Deleted content cannot be recovered.
                            
                            Users may report content that violates community guidelines. JamSlip reserves the right to review, moderate, and remove content at its sole discretion.
                            
                            JamSlip reserves the right to remove content that:
                            • Violates intellectual property rights
                            • Contains explicit illegal content
                            • Is abusive, offensive, harmful, or misleading
                            • Violates these Terms or Community Guidelines
                            """
                        )

                        section(
                            title: "6. Community Guidelines",
                            text: """
                            To maintain a safe and respectful environment, users agree not to upload or share content that:
                            • Contains explicit illegal content
                            • Infringes copyrights or intellectual property rights
                            • Promotes hate speech, harassment, or violence
                            • Contains unlawful, fraudulent, or deceptive material
                            
                            Violation of these guidelines may result in content removal or account suspension.
                            """
                        )

                        section(
                            title: "7. Free and Premium Accounts",
                            text: """
                            Free Users:
                            • Can like, repost, save content
                            • Can follow other users
                            • Can access public feeds
                            • May see advertisements
                            
                            Premium Users:
                            • Verified profile badge
                            • Unlimited Jam uploads
                            • Increased visibility of Jams
                            • Spatial audio features
                            • Ability to upload content
                            • Like, repost, save, and follow
                            """
                        )

                        section(
                            title: "8. Free Trial",
                            text: """
                            New users may receive a 3-day free trial.
                            
                            After the trial:
                            • The subscription automatically renews unless canceled
                            • Users may cancel at any time via their Apple subscription settings
                            """
                        )

                        section(
                            title: "9. Subscription & Payments",
                            text: """
                            JamSlip offers:
                            • Monthly subscription: $99 MXN
                            • Annual subscription: $1,000 MXN
                            
                            Payments are processed by Apple through in-app purchases.
                            JamSlip does not collect or store payment or banking information.
                            
                            Subscriptions automatically renew unless canceled at least 24 hours before the end of the billing period.
                            """
                        )

                        section(
                            title: "10. Account Deletion",
                            text: """
                            Users may permanently delete their account from the Settings section.
                            
                            Upon deletion:
                            • All Jams
                            • Likes
                            • Reposts
                            • Saved content
                            • Profile data
                            
                            Will be permanently removed.
                            This action is irreversible.
                            """
                        )

                        section(
                            title: "11. Notifications",
                            text: """
                            Push notifications may be enabled or disabled at any time in device settings or within the App.
                            """
                        )

                        section(
                            title: "12. Intellectual Property",
                            text: """
                            All trademarks, branding, and App content (excluding user-generated content) are the property of JamSlip.
                            
                            Unauthorized copying, distribution, or reproduction is prohibited.
                            """
                        )

                        section(
                            title: "13. Limitation of Liability",
                            text: """
                            JamSlip is provided "as is" without warranties of any kind.
                            
                            We are not responsible for:
                            • User-uploaded content
                            • External music content
                            • Service interruptions
                            • Third-party services
                            """
                        )

                        section(
                            title: "14. Termination",
                            text: """
                            We reserve the right to suspend or terminate accounts that violate these Terms.
                            """
                        )

                        section(
                            title: "15. Changes to Terms",
                            text: """
                            We may update these Terms at any time. Continued use of the App constitutes acceptance of changes.
                            """
                        )

                        section(
                            title: "16. Contact",
                            text: """
                            For questions regarding these Terms and Conditions, please contact:
                            
                            Email: jamslip@gmail.com
                            """
                        )

                        Spacer(minLength: 40)
                    }
                    .padding()
                }.scrollIndicators(.hidden)

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
                            .frame(width: 30, height: 30)
                            .background(Color.white.opacity(0.15))
                            .clipShape(Circle())
                    }
                }
            }
        }
    }

    // MARK: - Section Helper
    private func section(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 14) {

            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)

            Text(text)
                .font(.system(size: 14, weight: .regular)) // 👈 tamaño legal correcto
                .foregroundColor(Color.white.opacity(0.7))
                .lineSpacing(6)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.045))
        )
    }

}

