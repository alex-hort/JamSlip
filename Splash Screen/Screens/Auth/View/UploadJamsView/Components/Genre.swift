//
//  Genre.swift
//  Splash Screen
//
//  Created by Alexis Horteales Espinosa on 21/01/26.
//

import Foundation

enum Genre: String, CaseIterable {
    case pop = "Pop"
    case hipHop = "Hip-Hop / Rap"
    case rnb = "R&B"
    case rock = "Rock"
    case edm = "Electronic / EDM"
    case indie = "Indie"
    case alternative = "Alternative"
    case latin = "Latin"
    case reggaeton = "Reggaeton"
    case trap = "Trap"
    case regional = "Regional Mexicano"
    case corridos = "Corridos Tumbados"
    case banda = "Banda"
    case norteno = "Norteño"
    case salsa = "Salsa"
    case bachata = "Bachata"
    case cumbia = "Cumbia"
    case latinPop = "Latin Pop"
    case latinTrap = "Latin Trap"
}

enum Mood: String, CaseIterable {
    case happy, sad, romantic, nostalgic, melancholic
    case energetic, chill, dark, aggressive
    case party, sexy, motivational
}


