//
//  AboutView.swift
//  Splash Screen
//
//  Created by Alexis Horteales Espinosa on 12/02/26.
//

import SwiftUI


// MARK: - Legal View (Minimal Premium Style)

struct LegalView: View {

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {

                // MARK: - Background
                LinearGradient(
                    colors: [
                        Color.black,
                        Color(red: 0.07, green: 0.07, blue: 0.07)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 24) {

                    // MARK: - Legal Card
                    VStack(spacing: 0) {

                        legalRow(
                            title: "Terms of Service",
                            destination: TermsOfServiceView()
                        )

                        divider

                        legalRow(
                            title: "Privacy Policy",
                            destination: PrivacyPolicyView()
                        )
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 24)
                            .fill(Color.white.opacity(0.04))
                            .overlay(
                                RoundedRectangle(cornerRadius: 24)
                                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
                            )
                    )
                    .padding(.horizontal, 20)

                    Spacer() // 👈 empuja todo hacia arriba

                    // MARK: - App Version Footer
                    Text("Jamslip 1.0")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.35))
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 12)
                }

            }
            .navigationTitle("Legal")
            .navigationBarTitleDisplayMode(.inline)

            // MARK: - Back Button
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
            }
        }
    }

    // MARK: - Components

    private var divider: some View {
        Divider()
            .background(Color.white.opacity(0.08))
            .padding(.leading, 20)
    }

    private func legalRow<Destination: View>(
        title: String,
        destination: Destination
    ) -> some View {

        NavigationLink(destination: destination) {
            HStack {

                Text(title)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.white)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}


