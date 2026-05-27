//
//  LaunchScreen.swift
//  Splash Screen
//
//  Created by Alexis Horteales Espinosa on 04/01/26.
//
import SwiftUI

// Estructura principal del splash como Scene
struct LaunchScreen<RootView: View, Logo: View>: Scene {
    var config: LaunchScreenConfig = .init()
    @ViewBuilder var logo: () -> Logo
    @ViewBuilder var rootContent: () -> RootView
    
    var body: some Scene {
        WindowGroup {
            rootContent()
                .modifier(LaunchScreenModifier(config: config, logo: logo))
        }
    }
}

struct LaunchScreenConfig {
    var totalDuration: Double = 2.0       // Tiempo total que se ve el splash
    var fadeInDuration: Double = 0.6
    var fadeOutDuration: Double = 0.8
    var backgroundColor: Color = .black
    var logoSize: CGFloat = 80            // Tamaño pequeño por defecto
}

// Modifier que crea la ventana overlay
fileprivate struct LaunchScreenModifier<Logo: View>: ViewModifier {
    var config: LaunchScreenConfig
    @ViewBuilder var logo: () -> Logo
    
    @State private var isSplashVisible = true
    
    func body(content: Content) -> some View {
        ZStack {
            content
            
            if isSplashVisible {
                SimpleSplashView(config: config, logo: logo) {
                    // Al terminar la animación, ocultamos el splash
                    withAnimation(.easeOut(duration: 0.3)) {
                        isSplashVisible = false
                    }
                }
                .transition(.opacity)
            }
        }
        .ignoresSafeArea()
    }
}

// Vista del splash simple (sin ventanas extras, más estable)
fileprivate struct SimpleSplashView<Logo: View>: View {
    var config: LaunchScreenConfig
    @ViewBuilder var logo: () -> Logo
    var onComplete: () -> Void
    
    @State private var opacity: Double = 0.0
    
    var body: some View {
        ZStack {
            config.backgroundColor
                .ignoresSafeArea()
            
            logo()
               
                .opacity(opacity)
            
        }
        .onAppear {
            // Aparece suavemente
            withAnimation(.easeIn(duration: config.fadeInDuration)) {
                opacity = 1.0
            }
            
            // Espera y desaparece
            DispatchQueue.main.asyncAfter(deadline: .now() + config.totalDuration) {
                withAnimation(.easeOut(duration: config.fadeOutDuration)) {
                    opacity = 0.0
                } completion: {
                    onComplete()
                }
            }
        }
        .task {
            // Se ejecuta una sola vez cuando aparece el splash
            await PremiumMigrationScript.cleanupInvalidPremiumUsers()
        }
    }
    
}
