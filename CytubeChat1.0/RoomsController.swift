//
//  RoomsController.swift
//  CytubeChat
//
//  Created by Erik Little on 10/13/14.
//

import UIKit

class RoomsController: UIViewController, UITableViewDelegate, UITableViewDataSource, UIAlertViewDelegate  {
    
    @IBOutlet weak var tblRoom:UITableView!
    var inAlert:Bool = false
    var selectedRoom:CytubeRoom!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        defaultCenter.addObserver(forName: NSNotification.Name("roomRemoved"), object: nil, queue: nil) {[unowned self] not in
                self.tblRoom.reloadData()
        }
        defaultCenter.addObserver(self, selector: "handleSocketURLFail:",
            name: NSNotification.Name("socketURLFail"), object: nil)
    }
    
    override func viewDidAppear(_ animated:Bool) {
        tblRoom.reloadData()
        let room = roomMng.getActiveRoom()
        room?._setChatWindow(view: nil)
        room?.active = false
    }
    
    deinit {
        defaultCenter.removeObserver(self)
    }
    
    @IBAction func didLongPress(_ sender:UIGestureRecognizer) {
        if self.inAlert {
            return
        }
        
        self.inAlert = true
        let point = sender.location(in: tblRoom)
        let indexPath = tblRoom.indexPathForRow(at: point)
        if indexPath == nil {
            self.inAlert = false
            return
        }
        
        self.selectedRoom = roomMng.getRoomAtIndex(indexPath!.row)
        var connectDisconnect:String!
        let connected = selectedRoom.isConnected()
        if connected {
            connectDisconnect = "Disconnect"
        } else {
            connectDisconnect = "Connect"
        }
        let alert = UIAlertController(title: "Options", message: "What do you want to do?",
            preferredStyle: UIAlertController.Style.alert)
        let action = UIAlertAction(title: connectDisconnect, style: UIAlertAction.Style.default) {[weak self] action in
            if connected {
                self?.selectedRoom.closeRoom()
                self?.inAlert = false
                self?.selectedRoom = nil
            } else {
                if !(self?.selectedRoom.isConnected())! {
                    self?.selectedRoom.openSocket()
                }
                
                self?.selectedRoom.active = true
                self?.inAlert = false
                self?.selectedRoom = nil
                self?.performSegue(withIdentifier: "goToChatRoom", sender: self)
            }
        }
        
        let action1 = UIAlertAction(title: "Remove", style: UIAlertAction.Style.destructive) {[weak self] action in
            self?.selectedRoom.handleImminentDelete()
            self?.inAlert = false
            self?.selectedRoom = nil
        }
        let action2 = UIAlertAction(title: "Cancel", style: UIAlertAction.Style.cancel) {[weak self] action in
            self?.inAlert = false
            self?.selectedRoom = nil
        }
        
        alert.addAction(action)
        alert.addAction(action1)
        alert.addAction(action2)
        self.present(alert, animated: true, completion: nil)
    }
    
    func alertView(_ alertView: UIAlertView, clickedButtonAt buttonIndex: Int) {
        if buttonIndex == 1 && selectedRoom.isConnected() {
            self.selectedRoom.closeRoom()
        } else if (buttonIndex == 1 && !selectedRoom.isConnected()) {
            if !selectedRoom.isConnected() {
                selectedRoom.openSocket()
            }
            selectedRoom.active = true
            self.performSegue(withIdentifier: "goToChatRoom", sender: self)
        } else if buttonIndex == 2 {
            self.selectedRoom.handleImminentDelete()
        }
        
        self.selectedRoom = nil
        self.inAlert = false
    }
    
    // Called when a user selects a room
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let room = roomMng.getRoomAtIndex(indexPath.row)
        room.active = true
        self.performSegue(withIdentifier: "goToChatRoom", sender: self)
    }
    
    // Tells how many rows to redraw
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return roomMng.rooms.count
    }
    
    // Creates cells
    func tableView(_ tableView: UITableView, cellForRowAt indexPath:
        IndexPath) -> UITableViewCell {
            let cell: UITableViewCell = UITableViewCell(style: UITableViewCell.CellStyle.subtitle, reuseIdentifier: "roomsCell")
            
            roomMng.rooms[indexPath.row].cytubeRoom.roomsController = self
            cell.textLabel?.text = roomMng.rooms[indexPath.row].room
            cell.detailTextLabel?.text = roomMng.rooms[indexPath.row].server
            return cell
    }
    
    func handleSocketURLFail(_ not:Notification) {
        CytubeUtils.displayGenericAlertWithNoButtons(title: "Socket Failure",
            message: "Failed to load socketURL. Check you entered" +
            " the server correctly", view: self)
    }
}

