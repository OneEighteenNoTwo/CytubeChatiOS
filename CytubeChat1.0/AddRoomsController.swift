//
//  AddRoomsController.swift
//  CytubeChat
//
//  Created by Erik Little on 10/13/14.
//

import UIKit

class AddRoomsController: UIViewController, UITextFieldDelegate {
    
    @IBOutlet weak var serverText:UITextField!
    @IBOutlet weak var roomText:UITextField!
    @IBOutlet weak var passwordText:UITextField!
    
    // Add room was pressed
    @IBAction func btnAddTask(_ sender: UIButton) {
        self.handleAddRoom()
    }
    
    func handleAddRoom() {
        let room = roomText.text ?? ""
        let server = serverText.text ?? ""
        let password = passwordText.text ?? ""
        
        if server == "" || room == "" {
            CytubeUtils.displayGenericAlertWithNoButtons(title: "Error", message:
                "Please enter a valid server and room.", view: self)
            return
        }
        
        let hostReachability = Reachability(hostName: server)
        if hostReachability?.currentReachabilityStatus().rawValue == 0 {
            CytubeUtils.displayGenericAlertWithNoButtons(title: "Error", message:
                "Please check that you entered a valid server" +
                " and that you are connected to the internet.", view: self)
            return
        }
        
        // User is trying to add an existing room
        if roomMng.findRoom(room, server: server) != nil {
            CytubeUtils.displayGenericAlertWithNoButtons(title: "Already added", message:
                "You have already added this room!", view: self)
            return
        }
        let newRoom = CytubeRoom(roomName: room, server: server, password: password)
        CytubeUtils.addSocket(room: newRoom)
        roomMng.addRoom(server, room: room, cytubeRoom: newRoom)
        
        self.view.endEditing(true)
        self.serverText.reloadInputViews()
        self.roomText.text = nil
        self.passwordText.text = nil
        roomMng.saveRooms()
        self.tabBarController?.selectedIndex = 0
        
        if !UserDefaults.standard.bool(forKey: "HasLaunchedOnce") {
            CytubeUtils.displayGenericAlertWithNoButtons(title: "Hint",
                message: "Click on a room to join it." +
                " You can also long press on a room to bring up options for that room.", view: self)
            UserDefaults.standard.set(true, forKey: "HasLaunchedOnce")
            UserDefaults.standard.synchronize()
        }
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.view.endEditing(true)
    }
    
    func textFieldShouldReturn(_ textField:UITextField) -> Bool {
        textField.resignFirstResponder()
        self.handleAddRoom()
        return true
    }
}

