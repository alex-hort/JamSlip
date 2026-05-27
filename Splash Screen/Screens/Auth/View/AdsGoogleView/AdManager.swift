//
//  AdManager.swift
//  Splash Screen
//
//  Created by Alexis Horteales Espinosa on 28/01/26.
//

import Foundation
import GoogleMobileAds
import UIKit
import Combine

class AdManager: NSObject, ObservableObject, NativeAdLoaderDelegate {
    static let shared = AdManager()
    
    // ✅ AUTOMÁTICO: Test ID en DEBUG, tu ID real en RELEASE
    private var adUnitID: String {
        #if DEBUG
        // 🧪 DESARROLLO: Test Ad Unit ID de Google (siempre funciona)
        return "ca-app-pub-3940256099942544/3986624511"
        #else
        // 🚀 PRODUCCIÓN: Tu Ad Unit ID real (App Store)
        return "ca-app-pub-7808762386002485/1513584451"
        #endif
    }
    
    @Published var preloadedAds: [NativeAd] = []
    @Published var isLoading = false
    
    private var adLoader: AdLoader?
    private let maxPreloadedAds = 3
    
    private override init() {
        super.init()
        #if DEBUG
        print("🧪 AdManager: Modo DESARROLLO - Usando Test Ads")
        #else
        print("🚀 AdManager: Modo PRODUCCIÓN - Usando Ads Reales")
        #endif
        print("   Ad Unit ID: \(adUnitID)")
    }
    
    // MARK: - Preload Ads
    
    func preloadAds() {
        guard !isLoading && preloadedAds.count < maxPreloadedAds else {
            return
        }
        
        isLoading = true
        
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else {
            print("❌ AdManager: No rootViewController")
            isLoading = false
            return
        }
        
        adLoader = AdLoader(
            adUnitID: adUnitID,
            rootViewController: rootVC,
            adTypes: [.native],
            options: nil
        )
        adLoader?.delegate = self
        
        let request = Request()
        adLoader?.load(request)
        
        print("📢 AdManager: Precargando anuncio...")
    }
    
    // MARK: - Get Next Ad
    
    func getNextAd() -> NativeAd? {
        guard !preloadedAds.isEmpty else {
            print("⚠️ AdManager: No hay anuncios precargados, cargando...")
            preloadAds()
            return nil
        }
        
        let ad = preloadedAds.removeFirst()
        print("✅ AdManager: Devolviendo anuncio. Quedan: \(preloadedAds.count)")
        
        if preloadedAds.count < 2 {
            preloadAds()
        }
        
        return ad
    }
    
    // MARK: - NativeAdLoaderDelegate
    
    func adLoader(_ adLoader: AdLoader, didReceive nativeAd: NativeAd) {
        print("✅ AdManager: Anuncio recibido! Total: \(preloadedAds.count + 1)")
        
        DispatchQueue.main.async {
            self.preloadedAds.append(nativeAd)
            self.isLoading = false
            
            if self.preloadedAds.count < self.maxPreloadedAds {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.preloadAds()
                }
            }
        }
    }
    
    func adLoader(_ adLoader: AdLoader, didFailToReceiveAdWithError error: Error) {
        let nsError = error as NSError
        print("❌ AdManager: Error - \(error.localizedDescription)")
        print("   Código: \(nsError.code)")
        
        DispatchQueue.main.async {
            self.isLoading = false
            
            // Reintentar solo si no es "no fill"
            if nsError.code != 1 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                    self.preloadAds()
                }
            }
        }
    }
}


// ========================================
// CÓMO FUNCIONA:
// ========================================
//
// 🧪 DESARROLLO (DEBUG):
//    - Xcode compila con #if DEBUG = true
//    - Usa: ca-app-pub-3940256099942544/3986624511
//    - Ves anuncios de TEST de Google
//
// 🚀 PRODUCCIÓN (RELEASE):
//    - Xcode compila con #if DEBUG = false
//    - Usa: ca-app-pub-7808762386002485/1513584451
//    - Ves anuncios REALES de AdMob
//
// ✅ NO NECESITAS CAMBIAR NADA AL PUBLICAR
//    El código automáticamente usa el ID correcto
//
// ========================================
