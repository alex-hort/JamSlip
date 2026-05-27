//
//  InputView.swift
//  Splash Screen
//
//  Created by Alexis Horteales Espinosa on 05/01/26.
//

import SwiftUI

struct ElegantInputField: View {
    
    let placeholder: String
    let systemImage: String
    let isSecure: Bool
    
    @Binding var text: String
    
    @State private var isPasswordVisible = false
    @FocusState private var isFocused: Bool
    
    private var isSecureActive: Bool {
        isSecure && !isPasswordVisible
    }
    
    var body: some View {
        HStack(spacing: 12) {
            
            // ICON
            Image(systemName: systemImage)
                .foregroundStyle(isFocused ? .white : .gray)
                .frame(width: 20)
            
            // FIELD + CUSTOM PLACEHOLDER
            ZStack(alignment: .leading) {
                
                // Placeholder elegante
                Text(placeholder)
                    .foregroundStyle(.white.opacity(0.45))
                    .opacity(text.isEmpty ? 1 : 0)
                    .animation(.easeOut(duration: 0.15), value: text.isEmpty)
                    .allowsHitTesting(false)
                
                // Real input
                Group {
                    if isSecureActive {
                        SecureField("", text: $text)
                    } else {
                        TextField("", text: $text)
                    }
                }
                .focused($isFocused)
                .foregroundStyle(.white)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            }
            .frame(height: 22)
            
            Spacer()
            
            // 👁 Eye button
            if isSecure {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isPasswordVisible.toggle()
                    }
                } label: {
                    Image(systemName: isPasswordVisible ? "eye.slash.fill" : "eye.fill")
                        .foregroundStyle(.gray)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            isFocused
                            ? Color.white.opacity(0.6)
                            : Color.white.opacity(0.12),
                            lineWidth: 1
                        )
                )
        )
        .animation(.easeInOut(duration: 0.2), value: isFocused)
    }

}



struct AuthInputField: View {

    let placeholder: String
    let systemImage: String
    var isSecure: Bool = false

    @Binding var text: String

    // trailing states
    var showEye: Bool = false
    var trailingIcon: String? = nil
    var trailingColor: Color = .gray
    var isLoading: Bool = false

    @State private var revealPassword = false
    @FocusState private var focused: Bool

    private var secureActive: Bool {
        isSecure && !revealPassword
    }

    var body: some View {
        HStack(spacing: 12) {

            // LEFT ICON
            Image(systemName: systemImage)
                .foregroundStyle(focused ? .white : .gray)
                .frame(width: 22)

            // FIELD + PLACEHOLDER
            ZStack(alignment: .leading) {

                // PLACEHOLDER
                Text(placeholder)
                    .foregroundStyle(.white.opacity(0.45))
                    .opacity(text.isEmpty ? 1 : 0)
                    .animation(.easeOut(duration: 0.15), value: text.isEmpty)
                    .allowsHitTesting(false) // ✅ no bloquea el tap

                // REAL INPUT
                Group {
                    if secureActive {
                        SecureField("", text: $text)
                    } else {
                        TextField("", text: $text)
                    }
                }
                .focused($focused)
                .foregroundStyle(.white)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            }

            Spacer()
        


            // LOADING
            if isLoading {
                ProgressView()
                    .scaleEffect(0.7)
            }

            // TRAILING STATUS ICON
            if let trailingIcon {
                Image(systemName: trailingIcon)
                    .foregroundStyle(trailingColor)
            }

            // 👁 PASSWORD TOGGLE
            if showEye {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        revealPassword.toggle()
                    }
                } label: {
                    Image(systemName: revealPassword ? "eye.slash.fill" : "eye.fill")
                        .foregroundStyle(.gray)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(
                            focused
                            ? Color.white.opacity(0.5)
                            : Color.white.opacity(0.1),
                            lineWidth: 1
                        )
                )
        )
        .animation(.easeInOut(duration: 0.18), value: focused)
    }
}





