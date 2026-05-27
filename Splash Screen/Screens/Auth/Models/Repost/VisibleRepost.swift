//
//  VisibleRepost.swift
//  Splash Screen
//
//  Created by Alexis Horteales Espinosa on 17/01/26.
//

import Foundation
import SwiftUI

// MARK: - Visible Repost Model
struct VisibleRepost: Identifiable {
    let id: String
    let trackId: String
    let username: String
    let profileUrl: String?
    let trackTitle: String
    var comment: String?
    let color: Color
    let repostedAt: Date
    
    var timeAgo: String {
        let now = Date()
        let interval = now.timeIntervalSince(repostedAt)
        
        if interval < 60 {
            return "now"
        } else if interval < 3600 {
            let mins = Int(interval / 60)
            return "\(mins)m"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)h"
        } else {
            let days = Int(interval / 86400)
            return "\(days)d"
        }
    }
}

