//
//  MarqueeText.swift
//  Splash Screen
//
//  Created by Alexis Horteales Espinosa on 18/01/26.
//

import SwiftUI

struct MarqueeText: View {
    let text: String
    let font: Font
    var speed: Double = 30
    var delay: Double = 2.0
    
    @State private var textWidth: CGFloat = 0
    @State private var containerWidth: CGFloat = 0
    @State private var offset: CGFloat = 0
    @State private var animate: Bool = false
    
    private var needsScroll: Bool {
        textWidth > containerWidth && containerWidth > 0
    }
    
    private var distance: CGFloat {
        textWidth - containerWidth + 20
    }
    
    private var duration: Double {
        Double(distance) / speed
    }
    
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Texto que se mueve
                Text(text)
                    .font(font)
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .background(
                        GeometryReader { textGeo in
                            Color.clear
                                .preference(key: TextWidthKey.self, value: textGeo.size.width)
                        }
                    )
                    .offset(x: offset)
            }
            .frame(width: geo.size.width, alignment: .leading)
            .clipped()
            .onPreferenceChange(TextWidthKey.self) { width in
                textWidth = width
            }
            .onAppear {
                containerWidth = geo.size.width
                startAnimationIfNeeded()
            }
            .onChange(of: geo.size.width) { _, newValue in
                containerWidth = newValue
                resetAndStart()
            }
            .onChange(of: text) { _, _ in
                resetAndStart()
            }
        }
        .frame(height: 22)
    }
    
    private func startAnimationIfNeeded() {
        guard needsScroll else {
            offset = 0
            return
        }
        
        // Delay inicial antes de empezar
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            animateScroll()
        }
    }
    
    private func animateScroll() {
        guard needsScroll else { return }
        
        // Ir hacia la izquierda
        withAnimation(.linear(duration: duration)) {
            offset = -distance
        }
        
        // Esperar, resetear, y repetir
        DispatchQueue.main.asyncAfter(deadline: .now() + duration + delay) {
            // Reset instantáneo
            withAnimation(.linear(duration: 0)) {
                offset = 0
            }
            
            // Empezar de nuevo después de un pequeño delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                animateScroll()
            }
        }
    }
    
    private func resetAndStart() {
        offset = 0
        animate = false
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            startAnimationIfNeeded()
        }
    }
}

// Preference Key para medir el ancho del texto
struct TextWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}



