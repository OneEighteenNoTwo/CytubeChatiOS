//
//  AppDelegate.swift
//  CytubeChat
//
//  Created by Erik Little on 10/13/14.
//

import UIKit

@UIApplicationMain
	class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var window:UIWindow?
    var backgroundID:UIBackgroundTaskIdentifier!
    
    func application(_ application:UIApplication, didFinishLaunchingWithOptions launchOptions:[UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let cacheSizeMemory = 5*1024*1024 // 5MB
        let cacheSizeDisk = 32*1024*1024; // 32MB
        let sharedCache = URLCache(memoryCapacity: cacheSizeMemory,
            diskCapacity: cacheSizeDisk, diskPath: nil)
        URLCache.shared = sharedCache
        
        internetReachability?.startNotifier()
        roomMng.loadRooms()
        return true
    }
    
    func applicationWillResignActive(_ application:UIApplication) {
        // println("We are about to become inactive")
    }
    
    func applicationDidEnterBackground(_ application:UIApplication) {
        // println("We entered the background")
        self.backgroundID = application.beginBackgroundTask(expirationHandler: {[weak self] in
            if self != nil {
                application.endBackgroundTask(self!.backgroundID)
            }
        })
        
        DispatchQueue.global(qos: .userInitiated).async(execute: {
            // NSLog("Running in the background\n")
            roomMng.saveRooms()
            roomMng.closeRooms()
            application.endBackgroundTask(self.backgroundID)
        })
    }
    
    func applicationWillEnterForeground(_ application:UIApplication) {
        // println("Coming back from the background")
    }
    
    func applicationDidBecomeActive(_ application:UIApplication) {
        // println("We will become active")
        roomMng.reopenRooms()
    }
    
    func applicationWillTerminate(_ application:UIApplication) {
        // println("We're going down")
        roomMng.saveRooms()
    }
    
    func applicationDidReceiveMemoryWarning(_ application:UIApplication) {
        NSLog("Recieved memory warning, clearing url cache")
        let sharedCache = URLCache.shared
        sharedCache.removeAllCachedResponses()
    }
}

