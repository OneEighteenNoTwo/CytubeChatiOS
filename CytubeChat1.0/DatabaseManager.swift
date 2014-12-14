//
//  DatabaseManager.swift
//  CytubeChat
//
//  Created by Erik Little on 12/12/14.
//

import Foundation
import SQLite

class DatabaseManger: NSObject {
    let db:Database!
    
    override init() {
        super.init()
        var shouldCreateTables = true
        let paths = NSSearchPathForDirectoriesInDomains(NSSearchPathDirectory.DocumentDirectory,
            NSSearchPathDomainMask.UserDomainMask, true)
        
        let documentsDirectory = paths[0] as String
        let destPath = documentsDirectory.stringByAppendingPathComponent("cytubechat.db")
        if ((NSFileManager.defaultManager().fileExistsAtPath(destPath))) {
            shouldCreateTables = false
        }
        
        self.db = Database(destPath)
        if (shouldCreateTables) {
            self.createTables()
        }
    }
    
    func createTables() {
        let channels = db["channels"]
        let name = Expression<String>("name")
        let username = Expression<String>("username")
        let password = Expression<String>("password")
        let key = Expression<String>("key")
        self.db.create(table: channels) {t in
            t.column(name, unique: true)
            t.column(username)
            t.column(password)
            t.column(key)
        }
    }
    
    func getUsernamePasswordForChannel(#server:String, channel:String) -> (String, String)? {
        let channels = db["channels"]
        let name = Expression<String>("name")
        let username = Expression<String>("username")
        let password = Expression<String>("password")
        let key = Expression<String>("key")
        let query = channels.select(username, password, key).filter(name == (server + "." + channel))
        if (query.count == 1) {
            if let row = query.first {
                let passwordData = NSData(base64EncodedString: row[password], options: NSDataBase64DecodingOptions.allZeros)
                let upword = CytubeUtils.decryptPassword(passwordData!, key: row[key])
                if (upword != nil) {
                    return (row[username], upword!)
                }
            }
        }
        return nil
    }
    
    func insertEntryForChannel(#server:String, channel:String, uname:String, pword:String) {
        let channels = db["channels"]
        let name = Expression<String>("name")
        let username = Expression<String>("username")
        let password = Expression<String>("password")
        let key = Expression<String>("key")
        let completeChannel = server + "." + channel
        
        let key2 = CytubeUtils.generateKey()
        let ePassword = CytubeUtils.encryptPassword(pword, key: key2)
        
        if let insertedUser = channels.insert(name <- completeChannel, username <- uname, password <- ePassword, key <- key2) {
            println("inserted \(completeChannel) \(uname)")
        }
    }
    
    func removeEntryForChannel(#server:String, channel:String) {
        let channels = db["channels"]
        let name = Expression<String>("name")
        let channelToFind = server + "." + channel
        
        let foundChannel = channels.filter(name == channelToFind)
        foundChannel.delete()?
    }
}