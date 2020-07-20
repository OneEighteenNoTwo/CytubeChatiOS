//
//  CytubeRoom.swift
//  CytubeChat
//
//  Created by Erik Little on 10/13/14.
//

import Foundation
import SocketIO

final class CytubeRoom: NSObject {
    weak var chatWindow:ChatWindowController?
    weak var roomsController:RoomsController?
    weak var userlistView:UserlistController?
    let server:String!
    let roomName:String!
    var active = false
    var closed = false
    var connected = false
    var ignoreList = [String]()
    var kicked = false
    var loggedIn = false
    var messageBuffer = NSMutableArray()
    var needDelete = false
    var password:String!
    var roomPassword:String!
    var reconnecting = false
    var sentRoomPassword = false
    var shouldReconnect = true
    var socket:SocketIOClient?
    var manager:SocketManager?
    var socketIOURL:String!
    var userlist:[CytubeUser] = [CytubeUser]()
    var username:String!
    
    init(roomName:String, server:String, password:String?) {
        self.roomName = roomName
        self.roomPassword = password
        self.server = server
        super.init()
    }
    
    deinit {
        // println("CytubeRoom \(self.roomName) is being deinit")
        roomsController?.tblRoom.reloadData()
        defaultCenter.post(name:NSNotification.Name("roomRemoved"), object: nil)
    }
    
    func addHandlers() {
        // println("Adding Handlers for room: \(self.roomName)")
        	
        socket?.on(clientEvent: .connect) {[weak self] data, ack in
            self?.connected = true
            self?.reconnecting = false
            self?.socket?.emit("initChannelCallbacks")
            self?.socket?.emit("joinChannel", ["name": self!.roomName])
            self?.messageBuffer.removeAllObjects()
            self?.sendLogin()
        }
        
        socket?.on("disconnect") {[weak self] data, ack in
            if self == nil {
                return
            }
            
            if !self!.reconnecting {
                self?.connected = false
                self?.socketShutdown()
                self?.messageBuffer.removeAllObjects()
                self?.chatWindow?.messageView.reloadData()
            }
        }
        
        socket?.on("reconnect") {[weak self] data, ack in
            self?.connected = false
            self?.reconnecting = true
            self?.messageBuffer.removeAllObjects()
            self?.chatWindow?.messageView.reloadData()
        }
        
        socket?.on("chatMsg") {[weak self] data, ack in
            let data = data[0] as! NSDictionary
            self?.handleChatMsg(data:data)
        }
        
        socket?.on("login") {[weak self] data, ack in
            let data = data[0] as! NSDictionary
            let success = data["success"] as! Bool
            if success {
                self?.loggedIn = true
                self?.chatWindow?.chatInput.isEnabled = true
                self?.chatWindow?.loginButton.isEnabled = false
            } else {
                if let error = data["error"] as? String {
                    self?.loggedIn = false
                    self?.forgetUser()
                    self?.chatWindow?.chatInput.isEnabled = false
                    self?.chatWindow?.loginButton.isEnabled = true
                    CytubeUtils.displayGenericAlertWithNoButtons(title: "Login Failed", message: error,
                        view: self?.chatWindow)
                }
            }
        }
        
        socket?.on("userlist") {[weak self] data, ack in
            let data = data[0] as! NSArray
            self?.handleUserlist(userlist: data)
            self?.sortUserlist()
            self?.userlistView?.tblUserlist.reloadData()
        }
        
        socket?.on("addUser") {[weak self] data, ack in
            let data = data[0] as! [String: AnyObject]
            self?.handleAddUser(user:data)
        }
        
        socket?.on("userLeave") {[weak self] data, ack in
            let data = (data[0] as! NSDictionary)["name"] as! String
            self?.handleUserLeave(username:data)
        }
        
        socket?.on("setAFK") {[weak self] data, ack in
            let username = (data[0] as! NSDictionary)["name"] as! String
            let afk = (data[0] as! NSDictionary)["afk"] as! Bool
            self?.handleSetAFK(username:username, afk: afk)
        }
        
        socket?.on("kick") {[weak self] data, ack in
            let reason = (data[0] as! NSDictionary)["reason"] as! String
            let kickObj = [
                "reason": reason,
                "room": self!.roomName
            ]
            self?.kicked = true
            self?.shouldReconnect = false
            let nName = Notification.Name("wasKicked")
            defaultCenter.post(name: nName, object: kickObj)
        }
        
        socket?.on("needPassword") {[weak self] data, ack in
            if self?.roomPassword != nil && self?.roomPassword != "" {
                self?.handleRoomPassword()
            } else {
                defaultCenter.post(name: Notification.Name("passwordFail"), object: self)
                self?.handleImminentDelete()
            }
        }
        
        socket?.on("cancelNeedPassword") {[weak self] data, ack in
            self?.sentRoomPassword = false
            return
        }
        
        socket?.on("clearchat") {[weak self] data, ack in
            self?.clearChat()
            return
        }
    }
    
    func handleAddUser(user:[String: AnyObject]) {
        let tempUser = CytubeUser(user: user)
        if !CytubeUtils.userlistContainsUser(userlist: self.userlist, user: tempUser) {
            userlist.append(tempUser)
            sortUserlist()
            userlistView?.tblUserlist.reloadData()
        }
    }
    
    func handleChatMsg(data:NSDictionary) {
        let username = data["username"] as! String
        let msg = data["msg"] as! String
        let time = data["time"] as! TimeInterval / 1000
        let dateFormatter = DateFormatter()
        let date = NSDate(timeIntervalSince1970: time)
        dateFormatter.dateFormat = "HH:mm:ss z"
        
        if CytubeUtils.userIsIgnored(ignoreList: self.ignoreList, user: username) {
            let msgObjDict = [
                "time": "[" + dateFormatter.string(from:date as Date) + "]",
                "username": username,
                "msg": "User Ignored"
            ]
            return addMessageToChat(
                msg: CytubeUtils.createIgnoredUserMessage(msgObj: msgObjDict as NSDictionary))
        }
        
        let msgObj = [
            "time": "[" + dateFormatter.string(from: (date as Date))  + "]",
            "username": username,
            "msg": CytubeUtils.filterChatMsg(msg)
        ]
        
        addMessageToChat(msg: CytubeUtils.formatMessage(msgObj: msgObj as NSDictionary))
    }
    
    func handleImminentDelete() {
        if connected {
            // println("Imminent room deletion: Shut down socket")
            needDelete = true
            socket?.disconnect()
        } else {
            let index = roomMng.findRoomIndex(roomName, server: server)
            roomMng.removeRoom(index!)
        }
    }
    
    func handleRoomPassword() {
        if roomPassword != nil && !sentRoomPassword {
            socket?.emit("channelPassword", roomPassword)
            sentRoomPassword = true
        } else {
            defaultCenter.post(name: Notification.Name("passwordFail"), object: self)
            handleImminentDelete()
        }
    }
    
    func handleSetAFK(username:String, afk:Bool) {
        for user in userlist {
            if user.username == username {
                user.afk = afk
                userlistView?.tblUserlist.reloadData()
            }
        }
    }
    
    func handleUserLeave(username:String) {
        userlist = userlist.filter {!($0.username == username)}
        userlistView?.tblUserlist.reloadData()
    }
    
    func handleUserlist(userlist:NSArray) {
        self.userlist.removeAll(keepingCapacity: false)
        for user in userlist {
            self.userlist.append(CytubeUser(user: user as! [String: AnyObject]))
        }
    }
    
    func addMessageToChat(msg:NSAttributedString) {
        if messageBuffer.count > 75 {
            messageBuffer.removeObject(at: 0)
        }
        
        messageBuffer.add(msg)
        chatWindow?.messageView.reloadData()
        chatWindow?.scrollChat()
    }
    
    func clearChat() {
        messageBuffer.removeAllObjects()
        chatWindow?.messageView.reloadData()
    }
    
    func isConnected() -> Bool {
        if socket == nil {	
            return false
        }
        
        if socket?.status == SocketIOStatus.connected {
            return true
        } else {
            return false
        }
    }
    
    func saveUser() {
        if username == nil {
            return
        }
        
        dbManger?.insertEntryForChannel(server: server, channel: roomName,
            uname: username, pword: password!)
    }
    
    func forgetUser() {
        dbManger?.removeEntryForChannel(server: server, channel: roomName)
    }
    
    func sendChatMsg(msg:String?) {
        if !loggedIn || msg == nil {
            return
        }
        
        let msgData = [
            "msg": msg!
        ]
        socket?.emit("chatMsg", msgData)
    }
    
    func sendLogin() {
        if username != nil {
            let loginData = [
                "name": username,
                "pw": password
            ]
            socket?.emit("login", loginData)
        }
    }
    
    func setUpSocket() {
        if socketIOURL == nil {
            CytubeUtils.displayGenericAlertWithNoButtons(title: "Error",
                message: "Error getting server information", view: chatWindow)
            return
        }

        let sockUrl = URL(string: socketIOURL)
        manager = SocketManager(socketURL:  sockUrl!, config: [.log(true), .compress, .reconnects(false)])
        socket = manager?.defaultSocket
        
        addHandlers()
    }
    
    func sortUserlist() {
         userlist.sort()
    }
    
    func openSocket() {
        if !connected && socket != nil {
            kicked = false
            closed = false
            shouldReconnect = true
            if socket?.status != SocketIOStatus.connected && socket?.status != SocketIOStatus.connecting{
                socket!.connect()
            }
        } else if socket == nil {
            // Try and add the socket
            setUpSocket()
            kicked = false
            closed = false
            shouldReconnect = true
            socket?.connect()
        }
    }
    
    func closeSocket() {
        // NSLog("Closing socket for \(self.roomName)")
        socket?.disconnect()
        connected = false
        closed = true
        shouldReconnect = false
        userlist.removeAll(keepingCapacity: false)
        userlistView?.tblUserlist.reloadData()
        messageBuffer.removeAllObjects()
        chatWindow?.messageView.reloadData()
    }
    
    func socketShutdown() {
        // println("SOCKET SHUTDOWN")
        if needDelete {
            let index = roomMng.findRoomIndex(roomName, server: server)
            roomMng.removeRoom(index!)
        } else if closed && shouldReconnect {
            socket?.connect()
        }
    }
    
    func closeRoom() {
        if !connected {
            return
        }
        
        // NSLog("Closing room \(self.roomName)")
        socket?.disconnect()
        connected = false
        userlist.removeAll(keepingCapacity: false)
        messageBuffer.removeAllObjects()
        username = nil
        password = nil
        kicked = false
        chatWindow = nil
        userlistView = nil
        loggedIn = false
        active = false
        shouldReconnect = false
    }
    
    func setUserListView(view:UserlistController?) {
        userlistView = view
    }
    
    func _setChatWindow(view:ChatWindowController?) {
        chatWindow = view
    }
}
