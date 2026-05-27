//
//  View+Extensions.swift
//  Splash Screen
//
//  Created by Alexis Horteales Espinosa on 05/01/26.
//

import SwiftUI


//MARK: FORGOT PASSWORD VIEW
struct GradientButton: View {
    var title: String
    var icon: String
    var onClick: () -> ()
    
    var body: some View {
        Button(action: onClick, label: {
            HStack(spacing: 15) {
                Text(title)
                Image(systemName: icon)
            }
            .fontWeight(.bold)
            .foregroundStyle(.gray)
            .padding(.vertical, 12)
            .padding(.horizontal, 35)
        })
        
    }
}


struct CustomTF: View {
    
    // MARK: - Properties
    var sfIcon: String
    var iconTint: Color = .gray
    var hint: String
    var isPassword: Bool = false
    @Binding var value: String
    
    // MARK: - View Properties
    @State private var showPassword: Bool = false
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            
            Image(systemName: sfIcon)
                .foregroundStyle(iconTint)
            /// Same width to align TextFields equally
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 8) {
                
                if isPassword {
                    if showPassword {
                        TextField(hint, text: $value)
                    } else {
                        SecureField(hint, text: $value)
                    }
                } else {
                    TextField(hint, text: $value)
                }
                
                Divider()
            }
            .overlay(alignment: .trailing) {
                
                /// Password Reveal Button
                if isPassword {
                    Group{
                        if showPassword{
                            TextField(hint, text: $value)
                        } else{
                            SecureField(hint, text: $value)
                        }
                    }
                    Button {
                        withAnimation {
                            showPassword.toggle()
                        }
                    } label: {
                        Image(systemName: showPassword ? "eye.slash" : "eye")
                            .foregroundStyle(.gray)
                            .padding(10)
                            .contentShape(.rect)
                    }
                }
            }
        }
    }
}





/// Modelo para los tabs de la app
enum TabModel: String, CaseIterable {
    case home = "music.note.house"
    case search = "magnifyingglass"
    case notifications = "bell"
    case profile = "person"
    
    var title: String {
        switch self {
        case .home:
            return "Home"
        case .search:
            return "Search"
        case .notifications:
            return "Notifications"
        case .profile:
            return "Profile"
        }
    }
}
