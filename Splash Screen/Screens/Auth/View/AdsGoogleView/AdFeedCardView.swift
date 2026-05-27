//
//  AdFeedCardView.swift
//  Splash Screen
//
//  Created by Alexis Horteales Espinosa on 28/01/26.
//

import SwiftUI

struct AdFeedCardView: View {
    let adUnitID: String
    
    var body: some View {
        GeometryReader { geo in
            let cardWidth = geo.size.width - 32
            let cardHeight = geo.size.height - 200
            let cardOriginY: CGFloat = 20
            
            ZStack {
                Color.black
                
                VStack {
                    Spacer().frame(height: cardOriginY)
                    
                    ZStack {
                        // Fondo
                        RoundedRectangle(cornerRadius: 28)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.1, green: 0.1, blue: 0.15),
                                        Color(red: 0.05, green: 0.05, blue: 0.1)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: cardWidth, height: cardHeight * 1.12)
                            .shadow(color: .black.opacity(0.45), radius: 22, y: 12)
                        
                        // Anuncio
                        NativeAdViewRepresentable(adUnitID: adUnitID)
                            .frame(width: cardWidth - 40, height: cardHeight * 1.12 - 40)
                    }
                    .frame(width: cardWidth, height: cardHeight * 1.12)
                    .offset(y: 10)
                    
                    Spacer()
                }
            }
        }
    }
}
