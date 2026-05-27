//
//  Repost.swift
//  Splash Screen
//
//  Created by Alexis Horteales Espinosa on 16/01/26.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine



struct Repost: Identifiable, Codable, Equatable {
    var id: String { "\(odei)_\(trackId)" }
    let trackId: String
    let odei: String
    let username: String
    let userProfileUrl: String?
    let repostedAt: Date
    let trackTitle: String
    let trackArtist: String
    let trackArtistHandle: String
    let trackDuration: Int
    let trackImageUrl: String?
    var comment: String?
    
    static func == (lhs: Repost, rhs: Repost) -> Bool { lhs.id == rhs.id }
}

