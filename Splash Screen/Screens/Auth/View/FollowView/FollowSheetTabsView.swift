//
//  FollowSheetTabsView.swift
//  Splash Screen
//
//  Created by Alexis Horteales Espinosa on 15/01/26.
//

import SwiftUI

enum FollowSheetTab {
    case followers
    case following
}

struct FollowSheetTabsView: View {
    let followersCount: Int
    let followingCount: Int
    @Binding var selectedTab: FollowSheetTab
    
    var body: some View {
        HStack(spacing: 0) {
            // Followers tab
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedTab = .followers
                }
            } label: {
                VStack(spacing: 8) {
                    Text("\(followersCount) followers")
                        .font(.system(size: 15, weight: selectedTab == .followers ? .semibold : .regular))
                        .foregroundColor(selectedTab == .followers ? .white : .gray)
                    
                    Rectangle()
                        .fill(selectedTab == .followers ? Color.white : Color.clear)
                        .frame(height: 1)
                }
                .frame(maxWidth: .infinity)
            }
            
            // Following tab
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedTab = .following
                }
            } label: {
                VStack(spacing: 8) {
                    Text("\(followingCount) following")
                        .font(.system(size: 15, weight: selectedTab == .following ? .semibold : .regular))
                        .foregroundColor(selectedTab == .following ? .white : .gray)
                    
                    Rectangle()
                        .fill(selectedTab == .following ? Color.white : Color.clear)
                        .frame(height: 1)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.top, 8)
    }
}
