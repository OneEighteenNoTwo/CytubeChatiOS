//
//  CytubeUtils.swift
//  CytubeChat
//
//  Created by Erik Little on 10/15/14.
//

import UIKit

final class CytubeUtils {
    static let session = URLSession(configuration: .default)
    
    static func addSocket(room:CytubeRoom) {
        
        func findSocketURL(_ callback:(() -> Void)?) {
            let url =  "http://" + room.server + "/socketconfig/" + room.roomName + ".json"
            let request = URLRequest(url: URL(string: url)!)
            
            session.dataTask(with: request, completionHandler: {[weak room] data, res, err in
                if err != nil || data == nil {
                    DispatchQueue.main.async {
                        NSLog("Socket url fail:" + err!.localizedDescription)
                        defaultCenter.post(name: Notification.Name(rawValue: "socketURLFail"), object: nil)
                    }
                    return
                } else {
                    do {
                        let realJSON = try JSONSerialization.jsonObject(with: data!, options: .allowFragments)
                        if let innerDict  = realJSON as? [String: AnyObject] {
                            let servers = innerDict["servers"] as? [AnyObject]
                            for server in servers as! [AnyObject] {
                                if let dict = server as? [String:AnyObject]{
                                    if dict["secure"] as? Bool == true && dict["ipv6"] == nil {
                                        room?.socketIOURL = dict["url"] as! String
                                    } else if dict["ipv6"] == nil {
                                        room?.socketIOURL = dict["url"] as! String
                                    }
                                }
                            }
                        }
                        
                        callback?()
                    } catch {
                        findServerOldSchool(callback)
                    }
                }
                }) .resume()
        }
        
        func findServerOldSchool(_ callback: (() -> Void)?) {
            let url =  "http://" + room.server + "/sioconfig"
            let request = URLRequest(url: URL(string: url)!)
            
            session.dataTask(with: request, completionHandler: {[weak room] data, res, err in
                if err != nil || data == nil {
                    DispatchQueue.main.async {
                        NSLog("Socket url fail:" + err!.localizedDescription)
                        defaultCenter.post(name: Notification.Name(rawValue: "socketURLFail"), object: nil)
                    }
                    return
                } else {
                    var mutable = NSString(data: data!, encoding: String.Encoding.utf8.rawValue) as! String
                    if mutable["var IO_URLS="].matches().count == 0 {
                        DispatchQueue.main.async {
                            NSLog("Socket url fail")
                            defaultCenter.post(name: Notification.Name(rawValue: "socketURLFail"), object: nil)
                        }
                        return
                    }
                    mutable = mutable["var IO_URLS="] ~= ""
                    mutable = mutable["'"] ~= "\""
                    mutable[";var IO_URL=(.*)"] ~= ""
                    let jsonString = mutable[",IO_URL=(.*)"] ~= ""
                    let data = (jsonString as String).data(using: String.Encoding.utf8)
                    
                    do {
                        let JSONObject = try JSONSerialization.jsonObject(with: data!, options: .allowFragments)
                        if let dictionary = JSONObject as? [String: AnyObject] {
                            var ipv4SSL = dictionary["ipv4-ssl"] as? String
                            
                            if ipv4SSL != "" {
                                room?.socketIOURL = ipv4SSL
                            } else {
                                room?.socketIOURL = dictionary["ipv4-nossl"] as! String?
                            }
                            
                            callback?()
                            
                            
                            
                        }
    
                    } catch {
                        NSLog("Error getting socket config the old way")
                    }
                    
                }
                }) .resume()
        }
        
        // Find the url, and then set up the socket
        findSocketURL {[weak room] in room?.setUpSocket()}
    }
    
    static func filterChatMsg(_ data:String) -> String {
        var mut = data
        mut = mut["(&#39;)"] ~= "'"
        mut = mut["(&amp;)"] ~= "&"
        mut = mut["(&lt;)"] ~= "<"
        mut = mut["(&gt;)"] ~= ">"
        mut = mut["(&quot;)"] ~= "\""
        mut = mut["(&#40;)"] ~= "("
        mut = mut["(&#41;)"] ~= ")"
        mut = mut["(<img[^>]+src\\s*=\\s*['\"]([^'\"]+)['\"][^>]*>)"] ~= "$2"
        mut = mut["(<([^>]+)>)"] ~= ""
        mut = mut["(^[ \t]+)"] ~= ""
        
        return mut as String
    }
    
    static func encryptPassword(_ password:String, key:String) -> String? {
        do {
            let edata = try CytubeChatRNCryptor.encryptData(password.data(using: String.Encoding.utf8,
                allowLossyConversion: true), password: key)
            return edata.base64EncodedString(options: NSData.Base64EncodingOptions())
        } catch {
            return nil
        }
        
    }
    
    static func decryptPassword(_ edata:Data, key:String) -> String? {
        do {
            let pdata = try RNDecryptor.decryptData(edata, withPassword: key)
            return NSString(data: pdata, encoding: String.Encoding.utf8.rawValue) as! String
        } catch {
            return nil
        }
    }
    
    static func generateKey() -> String {
        var returnString = ""
        for _ in 0..<13 {
            let ran = arc4random_uniform(256)
            returnString += String(ran)
        }
        return returnString
    }
    
    static func displayGenericAlertWithNoButtons(title:String, message:String, view:UIViewController?) {
        DispatchQueue.main.async {
            let alert = UIAlertController(title: title, message: message, preferredStyle: UIAlertController.Style.alert)
            let action = UIAlertAction(title: "Okay", style: UIAlertAction.Style.default) {action in
                return
            }
            alert.addAction(action)
            view?.present(alert, animated: true, completion: nil)
        }
    }
    
    static func userlistContainsUser(userlist:[CytubeUser], user:CytubeUser) -> Bool {
        for cuser in userlist {
            if cuser === user {
                return true
            }
        }
        return false
    }
    
    static func userIsIgnored(ignoreList:[String], user:String) -> Bool {
        if ignoreList.count == 0 {
            return false
        }
        
        for cuser in ignoreList {
            if let userAsCytubeUser = user as? CytubeUser {
                if cuser == userAsCytubeUser.username {
                    return true
                }
            } else if let userAsString = user as? String {
                if cuser == userAsString {
                    return true
                }
            }
        }
        return false
    }
    
    static func formatMessage(msgObj:NSDictionary) -> NSAttributedString {
        let time = msgObj["time"] as! String
        let username = msgObj["username"] as! String
        let msg = msgObj["msg"] as! String
        let message = NSString(format: "%@ %@: %@", time, username, msg)
        let returnMessage = NSMutableAttributedString(string: message as String)
        let timeFont = UIFont(name: "Helvetica Neue", size: 10)
        let timeRange = message.range(of: time)
        let usernameFont = UIFont.boldSystemFont(ofSize: 12)
        let usernameRange = message.range(of: username + ":")
        
        returnMessage.addAttribute(NSAttributedString.Key(String(kCTFontAttributeName)), value: timeFont!, range: timeRange)
        returnMessage.addAttribute(NSAttributedString.Key(String(kCTFontAttributeName)), value: usernameFont, range: usernameRange)
        return returnMessage
    }
    
    static func createIgnoredUserMessage(msgObj:NSDictionary) -> NSAttributedString {
        let time = msgObj["time"] as! String
        let username = msgObj["username"] as! String
        let msg = msgObj["msg"] as! String
        let message = NSString(format: "%@ %@: %@", time, username, msg)
        let returnMessage = NSMutableAttributedString(string: message as String)
        let messageRange = message.range(of: msg)
        let messageFont = UIFont.boldSystemFont(ofSize: 12)
        let timeFont = UIFont(name: "Helvetica Neue", size: 10)
        let timeRange = message.range(of: time)
        let usernameFont = UIFont.boldSystemFont(ofSize: 12)
        let usernameRange = message.range(of: username + ":")
        
        returnMessage.addAttribute(NSAttributedString.Key(String(kCTFontAttributeName)), value: timeFont!, range: timeRange)
        returnMessage.addAttribute(NSAttributedString.Key(String(kCTFontAttributeName)), value: usernameFont, range: usernameRange)
        returnMessage.addAttribute(NSAttributedString.Key(String(kCTFontAttributeName)), value: messageFont, range: messageRange)
        return returnMessage
        
    }
}
