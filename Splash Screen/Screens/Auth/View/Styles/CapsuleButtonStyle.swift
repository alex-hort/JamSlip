//
//  CapsuleButtonStyle.swift
//  Splash Screen
//
//  Created by Alexis Horteales Espinosa on 05/01/26.
//


import SwiftUI

struct CapsuleButtonStyle: ButtonStyle{
    
    //properties
    var bgColor: Color = .white
    var textColor: Color = .black
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.black)
            .padding()
            .frame(maxWidth: .infinity)
            .background(Capsule().fill(bgColor))
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
        
    }
}
