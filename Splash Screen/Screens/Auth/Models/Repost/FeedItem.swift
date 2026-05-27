//
//  FeedItem.swift
//  Splash Screen
//
//  Created by Alexis Horteales Espinosa on 16/01/26.
//
import Foundation

enum FeedItem: Identifiable, Equatable {
    case track(AudiusTrack)
    case repost(Repost, AudiusTrack)
    case ad(String, String) // adUnitID, uniqueID
    
    var id: String {
        switch self {
        case .track(let track): return "t_\(track.id)"
        case .repost(let repost, _): return "r_\(repost.id)"
        case .ad(_, let uniqueID): return "ad_\(uniqueID)"
        }
    }
    
    var track: AudiusTrack {
        switch self {
        case .track(let track): return track
        case .repost(_, let track): return track
        case .ad:
            return AudiusTrack(
                id: "ad_dummy",
                title: "Ad",
                duration: 0,
                artwork: nil,
                coverPhoto: nil,
                user: AudiusUser(name: "Ad", handle: "ad"),
                playCount: nil,
                favoriteCount: nil
            )
        }
    }
    
    var repostInfo: Repost? {
        if case .repost(let repost, _) = self { return repost }
        return nil
    }
    
    var isAd: Bool {
        if case .ad = self { return true }
        return false
    }
    
    var adUnitID: String? {
        if case .ad(let unitID, _) = self { return unitID }
        return nil
    }
    
    static func == (lhs: FeedItem, rhs: FeedItem) -> Bool {
        lhs.id == rhs.id
    }
}
