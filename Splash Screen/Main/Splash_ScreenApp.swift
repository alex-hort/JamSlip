//
//  Splash_ScreenApp.swift
//  Splash Screen
//
//  Created by Alexis Horteales Espinosa on 04/01/26.
//

import SwiftUI
import FirebaseCore
import GoogleMobileAds


class AppDelegate: NSObject, UIApplicationDelegate {
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    FirebaseApp.configure()
      
    // Inicializar AdMob
    MobileAds.shared.start()

    return true
  }
}

@main
struct Splash_ScreenApp: App {

    /// AQUÍ se crea el ViewModel (una sola vez)
    @StateObject private var authVM = AuthViewModel()

    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
 

    var body: some Scene {
        LaunchScreen(
            config: LaunchScreenConfig(
                totalDuration: 2.2,
                fadeInDuration: 0.7,
                fadeOutDuration: 0.9
            ),
            logo: {
                Image(.logo)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)
            },
            rootContent: {
                RootView()
                    .environmentObject(authVM) 
            }
        )
    }
}

