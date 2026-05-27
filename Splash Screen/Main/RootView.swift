//
//  RootView.swift
//  Splash Screen
//
//  Created by Alexis Horteales Espinosa on 05/01/26.
//


import SwiftUI

struct RootView: View {
    
    @EnvironmentObject var authVM: AuthViewModel
    
    var body: some View {
        Group {
            if authVM.userSession != nil {
                MainTabView()   /// Usuario logueado
            } else {
                LoginView()
            }
        }
    }
}


