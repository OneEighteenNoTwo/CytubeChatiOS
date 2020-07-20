//
//  Globals.swift
//  CytubeChat
//
//  Created by Erik Little on 10/31/14.
//

import Foundation

let dbManger = DatabaseManger()
let defaultCenter = NotificationCenter.default
let internetReachability = Reachability.forInternetConnection()
let roomMng = RoomManager()

func ==(lhs:CytubeUser, rhs:CytubeUser) -> Bool {
    if lhs.username == rhs.username {
        return true
    }
    
    return false
}

func <(lhs:CytubeUser, rhs:CytubeUser) -> Bool {
    if lhs.rank < rhs.rank {
        return true
    } else if lhs.rank == rhs.rank
        && lhs.username.lowercased() > rhs.username.lowercased() {
        return true
    }
    
    return false
}

func ===(lhs:CytubeUser, rhs:CytubeUser) -> Bool {
    if lhs == rhs && lhs.username == rhs.username {
        return true
    }
    
    return false
}
