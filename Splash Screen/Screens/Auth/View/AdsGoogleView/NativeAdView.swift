//
//  NativeAdView.swift
//  Splash Screen
//
//  Created by Alexis Horteales Espinosa on 26/01/26.
//
//

import SwiftUI
import GoogleMobileAds

struct NativeAdViewRepresentable: UIViewRepresentable {
    let adUnitID: String
    @StateObject private var adManager = AdManager.shared
    
    func makeUIView(context: Context) -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = .clear
        
        let adView = NativeAdView()
        adView.backgroundColor = .clear
        adView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(adView)
        
        NSLayoutConstraint.activate([
            adView.topAnchor.constraint(equalTo: containerView.topAnchor),
            adView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            adView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            adView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor)
        ])
        
        context.coordinator.adView = adView
        context.coordinator.containerView = containerView
        
        // Usar anuncio precargado si existe
        if let preloadedAd = AdManager.shared.getNextAd() {
            print("🎯 Usando anuncio precargado")
            context.coordinator.configureAdView(adView: adView, nativeAd: preloadedAd)
            adView.nativeAd = preloadedAd
        } else {
            print("⏳ No hay anuncio precargado, cargando...")
            context.coordinator.loadAd(adUnitID: adUnitID)
        }
        
        return containerView
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // No actualizar - mantener el anuncio actual
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, NativeAdLoaderDelegate, NativeAdDelegate {
        var adView: NativeAdView?
        var containerView: UIView?
        var adLoader: AdLoader?
        var currentAd: NativeAd?
        
        func loadAd(adUnitID: String) {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let rootVC = windowScene.windows.first?.rootViewController else {
                print("❌ No se encontró rootViewController")
                return
            }
            
            adLoader = AdLoader(
                adUnitID: adUnitID,
                rootViewController: rootVC,
                adTypes: [.native],
                options: nil
            )
            adLoader?.delegate = self
            adLoader?.load(Request())
            
            print("📢 Cargando anuncio nativo...")
        }
        
        // MARK: - NativeAdLoaderDelegate
        
        func adLoader(_ adLoader: AdLoader, didReceive nativeAd: NativeAd) {
            print("✅ Anuncio nativo recibido!")
            
            guard let adView = adView else {
                print("❌ adView es nil")
                return
            }
            
            currentAd = nativeAd
            nativeAd.delegate = self
            
            DispatchQueue.main.async {
                adView.subviews.forEach { $0.removeFromSuperview() }
                self.configureAdView(adView: adView, nativeAd: nativeAd)
                adView.nativeAd = nativeAd
            }
        }
        
        func adLoader(_ adLoader: AdLoader, didFailToReceiveAdWithError error: Error) {
            print("❌ Error cargando anuncio: \(error.localizedDescription)")
        }
        
        // MARK: - NativeAdDelegate
        
        func nativeAdDidRecordClick(_ nativeAd: NativeAd) {
            print("👆 Click en anuncio")
        }
        
        func nativeAdDidRecordImpression(_ nativeAd: NativeAd) {
            print("👁 Impresión de anuncio")
        }
        
        // MARK: - Configure Ad View
        
        func configureAdView(adView: NativeAdView, nativeAd: NativeAd) {
            // Limpiar vistas anteriores
            adView.subviews.forEach { $0.removeFromSuperview() }
            
            let containerStack = UIStackView()
            containerStack.axis = .vertical
            containerStack.spacing = 16
            containerStack.layoutMargins = UIEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
            containerStack.isLayoutMarginsRelativeArrangement = true
            containerStack.translatesAutoresizingMaskIntoConstraints = false
            
            // Badge "Sponsored"
            let adBadge = UILabel()
            adBadge.text = "Sponsored"
            adBadge.font = .systemFont(ofSize: 11, weight: .semibold)
            adBadge.textColor = .white
            adBadge.backgroundColor = UIColor.systemYellow.withAlphaComponent(0.9)
            adBadge.textAlignment = .center
            adBadge.layer.cornerRadius = 6
            adBadge.clipsToBounds = true
            adBadge.translatesAutoresizingMaskIntoConstraints = false
            
            // Header Stack
            let headerStack = UIStackView()
            headerStack.axis = .horizontal
            headerStack.spacing = 14
            headerStack.alignment = .center
            
            // Icon
            let iconView = UIImageView()
            iconView.contentMode = .scaleAspectFit
            iconView.image = nativeAd.icon?.image
            iconView.layer.cornerRadius = 12
            iconView.clipsToBounds = true
            iconView.backgroundColor = UIColor.white.withAlphaComponent(0.1)
            iconView.translatesAutoresizingMaskIntoConstraints = false
            adView.iconView = iconView
            
            // Headline
            let headlineLabel = UILabel()
            headlineLabel.font = .systemFont(ofSize: 20, weight: .bold)
            headlineLabel.numberOfLines = 2
            headlineLabel.text = nativeAd.headline
            headlineLabel.textColor = .white
            adView.headlineView = headlineLabel
            
            headerStack.addArrangedSubview(iconView)
            headerStack.addArrangedSubview(headlineLabel)
            
            // Body
            let bodyLabel = UILabel()
            bodyLabel.font = .systemFont(ofSize: 16)
            bodyLabel.numberOfLines = 3
            bodyLabel.textColor = .white.withAlphaComponent(0.85)
            bodyLabel.text = nativeAd.body
            bodyLabel.isHidden = nativeAd.body == nil
            adView.bodyView = bodyLabel
            
            // Spacer
            let spacer = UIView()
            spacer.setContentHuggingPriority(.defaultLow, for: .vertical)
            
            // CTA Button
            let ctaButton = UIButton(type: .system)
            ctaButton.backgroundColor = UIColor.systemBlue
            ctaButton.setTitleColor(.white, for: .normal)
            ctaButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
            ctaButton.layer.cornerRadius = 12
            ctaButton.setTitle(nativeAd.callToAction ?? "Learn More", for: .normal)
            ctaButton.translatesAutoresizingMaskIntoConstraints = false
            ctaButton.isUserInteractionEnabled = false
            adView.callToActionView = ctaButton
            
            // Add to stack
            containerStack.addArrangedSubview(adBadge)
            containerStack.addArrangedSubview(headerStack)
            if !bodyLabel.isHidden {
                containerStack.addArrangedSubview(bodyLabel)
            }
            containerStack.addArrangedSubview(spacer)
            containerStack.addArrangedSubview(ctaButton)
            
            adView.addSubview(containerStack)
            
            NSLayoutConstraint.activate([
                containerStack.topAnchor.constraint(equalTo: adView.topAnchor),
                containerStack.leadingAnchor.constraint(equalTo: adView.leadingAnchor),
                containerStack.trailingAnchor.constraint(equalTo: adView.trailingAnchor),
                containerStack.bottomAnchor.constraint(equalTo: adView.bottomAnchor),
                adBadge.heightAnchor.constraint(equalToConstant: 24),
                adBadge.widthAnchor.constraint(equalToConstant: 90),
                iconView.widthAnchor.constraint(equalToConstant: 50),
                iconView.heightAnchor.constraint(equalToConstant: 50),
                ctaButton.heightAnchor.constraint(equalToConstant: 50)
            ])
        }
    }
}
