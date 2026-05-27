//
//  ProfileTabsView.swift
//  Splash Screen
//
//  Created by Alexis Horteales Espinosa on 08/01/26.
//

import SwiftUI

struct ProfileTabsView: View {
    
    @Binding var selectedTab: ProfileTab
    
    var body: some View {
        HStack(spacing: 0) {
            TabButton(
                title: "Jams",
                isSelected: selectedTab == .jams
            ) {
                selectedTab = .jams
            }
            
            TabButton(
                title: "Saved",
                isSelected: selectedTab == .saved
            ) {
                selectedTab = .saved
            }
            
            TabButton(
                title: "Liked",
                isSelected: selectedTab == .liked
            ) {
                selectedTab = .liked
            }
        }
        .padding(.top, 10)
        .background(Color.black)
    }
}


struct TabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundColor(isSelected ? .white : .white.opacity(0.6))
                
                Rectangle()
                    .fill(isSelected ? Color.indigo : Color.clear)
                    .frame(height: 3)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}
