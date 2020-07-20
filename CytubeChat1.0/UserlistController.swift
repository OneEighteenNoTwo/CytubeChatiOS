//
//  UserlistController.swift
//  CytubeChat
//
//  Created by Erik Little on 10/20/14.
//

import UIKit

class UserlistController: UIViewController, UITableViewDelegate, UITableViewDataSource, UIAlertViewDelegate {
    
    @IBOutlet weak var userlistTitle:UINavigationItem!
    @IBOutlet weak var tblUserlist:UITableView!
    weak var room:CytubeRoom!
    weak var selectedUser:CytubeUser!
    var inAlert = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.room = roomMng.getActiveRoom()
        self.userlistTitle.title = room.roomName + " userlist"
        self.room.setUserListView(view:self)
        self.tblUserlist.reloadData()
        
        if !UserDefaults.standard.bool(forKey: "HasSeenUserlist") {
            CytubeUtils.displayGenericAlertWithNoButtons(title: "Hint",
                message: "You can view a users profile by tapping on that user. Also, if that" +
                " user is annoying you, long press on their name to bring up options to ignore them.",
                view: self)
        }
        
        UserDefaults.standard.set(true, forKey: "HasSeenUserlist")
        UserDefaults.standard.synchronize()
    }
    
    override func viewDidAppear(_ animated:Bool) {
        self.tblUserlist.reloadData()
    }
    
    override func viewDidDisappear(_ animated:Bool) {
        self.room.setUserListView(view:nil)
    }
    
    override func prepare(for segue:UIStoryboardSegue, sender:Any?) {
        if let segueIdentifier = segue.identifier {
            if segueIdentifier == "showProfile" {
                (segue.destination as! ProfileViewController).user = self.selectedUser
            }
        }
    }
    
    @IBAction func backBtnClicked(_ btn:UIBarButtonItem) {
        self.dismiss(animated: true, completion: nil)
    }
    
    @IBAction func didLongPress(_ sender:UIGestureRecognizer) {
        if self.inAlert {
            return
        }
        
        self.inAlert = true
        let point = sender.location(in: self.tblUserlist)
        let indexPath = self.tblUserlist.indexPathForRow(at: point)
        if indexPath == nil {
            self.inAlert = false
            return
        }
        
        self.selectedUser = self.room.userlist[indexPath!.row]
        if self.selectedUser.username.lowercased()
            == self.room.username?.lowercased() {
                return
        }
        self.showIgnoreUserAlert(user: self.selectedUser)
    }
    
    func tableView(_ tableView:UITableView, numberOfRowsInSection section:Int) -> Int {
        return self.room.userlist.count
    }
    
    func tableView(_ tableView:UITableView,
        cellForRowAt indexPath:IndexPath) -> UITableViewCell {
            let cell = UITableViewCell(style: UITableViewCell.CellStyle.subtitle, reuseIdentifier: "userlistCell")
            let user = self.room.userlist[indexPath.row]
            
            cell.textLabel?.attributedText = user.createAttributedStringForUser()
            return cell
    }
    
    func tableView(_ tableView:UITableView, didSelectRowAt indexPath:IndexPath) {
        self.selectedUser = self.room.userlist[indexPath.row]
        
        if self.selectedUser != nil {
            if self.selectedUser.profileText == ""
                && self.selectedUser.profileImage == nil {
                return
            }
            self.performSegue(withIdentifier: "showProfile", sender: self)
        }
    }
    
    func showIgnoreUserAlert(user:CytubeUser) {
        var title:String!
        var message:String!
        if CytubeUtils.userIsIgnored(ignoreList: self.room.ignoreList, user: user.username) {
            title = "Unignore"
            message = "Unignore \(user.username)?"
        } else {
            title = "Ignore"
            message = "Ignore \(user.username)?"
        }
        
        let alert = UIAlertController(title: title, message:
            message, preferredStyle: UIAlertController.Style.alert)
        let yesAction = UIAlertAction(title: "Yes", style: UIAlertAction.Style.default) {alert in
            if title == "Unignore" {
                for i in 0..<self.room.ignoreList.count {
                    if self.room.ignoreList[i] == self.selectedUser.username {
                        self.room.ignoreList.remove(at: i)
                    }
                }
                self.inAlert = false
            } else {
                self.room.ignoreList.append(self.selectedUser.username)
                self.inAlert = false
            }
        }
        let noAction = UIAlertAction(title: "No", style: UIAlertAction.Style.cancel) {alert in
            self.inAlert = false
            return
        }
        alert.addAction(yesAction)
        alert.addAction(noAction)
        self.present(alert, animated: true, completion: nil)
    }
}
