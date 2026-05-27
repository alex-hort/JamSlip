//
//  NotificationsSettingsView.swift
//  Splash Screen
//
//  Created by Alexis Horteales Espinosa on 12/02/26.
//

import SwiftUI

// MARK: - Notifications Settings View
struct NotificationsSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var pushNotifications = true

    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Push Notifications Section
                        VStack(spacing: 14) {
                            sectionHeader("Push Notifications")
                            
                            VStack(spacing: 1) {
                                toggleRow(
                                    title: "Enable Push Notifications",
                                    subtitle: "Receive notifications on this device",
                                    isOn: $pushNotifications
                                )
                            }
                            .background(
                                RoundedRectangle(cornerRadius: 18)
                                    .fill(Color.white.opacity(0.05))
                            )
                        }
                        
                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 20)
                }
                
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                }
            }
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
            .padding(.leading, 16)
    }
    
    private func toggleRow(title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 17))
                    .foregroundColor(.white)
                
                Text(subtitle)
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(Color.white.opacity(0.6))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }
}
