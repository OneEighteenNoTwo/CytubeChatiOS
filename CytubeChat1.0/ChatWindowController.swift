//
//  ChatWindowController.swift
//  CytubeChat
//
//  Created by Erik Little on 10/13/14.
//

import UIKit

private let sizingView = UITextView()

class ChatWindowController: UIViewController, UITableViewDataSource, UITableViewDelegate, UIAlertViewDelegate, UITextFieldDelegate {
    
    @IBOutlet weak var roomTitle:UIButton!
    @IBOutlet weak var messageView:UITableView!
    @IBOutlet weak var chatInput:UITextField!
    @IBOutlet weak var loginButton:UIBarButtonItem!
    @IBOutlet weak var inputBottomLayoutGuide:NSLayoutConstraint!
    weak var room:CytubeRoom!
    let tapRec = UITapGestureRecognizer()
    var canScroll:Bool = true
    var keyboardIsShowing = false
    var loggedIn:Bool = false
    var keyboardOffset:CGFloat!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.room = roomMng.getActiveRoom()
        if self.room != nil {
            if (room!.loggedIn) {
                self.loginButton.isEnabled = false
                self.chatInput.isEnabled = true
            }
        }
        self.room?._setChatWindow(view:self)
        self.roomTitle.setTitle(self.room?.roomName, for: UIControl.State())
        self.tapRec.addTarget(self, action: #selector(self.tappedMessages))
        self.messageView.addGestureRecognizer(self.tapRec)
    }

    override func viewDidAppear(_ animated:Bool) {
        super.viewDidAppear(true)
        defaultCenter.addObserver(self, selector: #selector(keyboardWillShow(_:)),
                                  name: UIResponder.keyboardWillShowNotification,
                                  object: nil)
        defaultCenter.addObserver(self, selector: #selector(self.keyboardWillHide(_:)),
            name: UIResponder.keyboardWillHideNotification, object: nil)
        defaultCenter.addObserver(self, selector: "wasKicked:",
            name: NSNotification.Name("wasKicked"), object: nil)
        defaultCenter.addObserver(self, selector: "passwordFail:",
            name: NSNotification.Name("passwordFail"), object: nil)
        defaultCenter.addObserver(self, selector: "handleNilSocketURL:",
            name: NSNotification.Name("nilSocketURL"), object: nil)
        defaultCenter.addObserver(self, selector: "handleNoInternet:",
            name: NSNotification.Name("noInternet"), object: nil)
        defaultCenter.addObserver(self, selector: "handleSocketURLFail:",
            name:NSNotification.Name("socketURLFail"), object: nil)
        defaultCenter.addObserver(self, selector: "handleSocketTimeout:",
            name: NSNotification.Name("socketTimeout"), object: nil)
        
        if self.room.kicked {
            // TODO Save the kick reason
            self.wasKicked(Notification(name: NSNotification.Name("wasKicked"), object: [
                "room": self.room.roomName,
                "reason": ""
                ]))
            return
        }
        
        keyboardOffset = inputBottomLayoutGuide.constant
        
        self.scrollChat()
        // Start connection to server
        if !self.room.isConnected() {
            self.room.openSocket()
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        defaultCenter.removeObserver(self)
    }
    
    override func prepare(for segue:UIStoryboardSegue, sender:Any?) {
        if let segueIdentifier = segue.identifier {
            if segueIdentifier == "openChatLink" {
                let cell = sender as! ChatCell
                (segue.destination as! ChatLinkController).link = cell.link
            }
        }
    }
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        self.canScroll = false
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        self.canScroll = true
    }
    
    @objc
    func keyboardWillShow(_ not:Notification) {
        if self.keyboardIsShowing {
            return
        }
        
        self.keyboardIsShowing = true
        self.canScroll = true
        //let scrollNum = room?.messageBuffer.count
        let info = not.userInfo!
        let keyboardFrame = (info[UIResponder.keyboardFrameEndUserInfoKey] as! NSValue).cgRectValue

        UIView.animate(withDuration: 0.3, animations: {
            self.inputBottomLayoutGuide.constant = keyboardFrame.size.height + 10
        })
        
        let time = DispatchTime.now() + Double(Int64(0.01)) / Double(NSEC_PER_SEC)
        
        DispatchQueue.main.asyncAfter(deadline: time) {self.scrollChat()}
    }
    
    @objc
    func keyboardWillHide(_ not:Notification) {
        self.canScroll = true
        self.keyboardIsShowing = false
        
        UIView.animate(withDuration: 0.3, animations: {[weak self] in
            if let this = self {
                this.inputBottomLayoutGuide.constant = this.keyboardOffset
            }
        })
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if room != nil {
            return room!.messageBuffer.count
        } else {
            return 0
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath:IndexPath) -> CGFloat {
        return self.heightForRowAtIndexPath(indexPath)
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = messageView.dequeueReusableCell(withIdentifier: "chatWindowCell")! as UITableViewCell
        let font = UIFont(name: "Helvetica Neue", size: 12)
        (cell.contentView.subviews[0] as! UITextView).font = font
        (cell.contentView.subviews[0] as! UITextView).text = nil
        (cell.contentView.subviews[0] as! UITextView).attributedText =
            self.room?.messageBuffer.object(at: indexPath.row) as! NSMutableAttributedString
        
        return cell
    }
    
    func heightForRowAtIndexPath(_ indexPath:IndexPath) -> CGFloat {
        sizingView.attributedText = room?.messageBuffer.object(at: indexPath.row)
            as! NSMutableAttributedString
        
        let width = self.messageView.frame.size.width
        let size = sizingView.sizeThatFits(CGSize(width: width, height: 120.0))
        
        return size.height + 3 // Need some padding
    }
    
    // Hide keyboard if we touch anywhere
    @objc
    func tappedMessages() {
        self.view.endEditing(true)
        messageView.reloadData()
    }
    
    func textFieldShouldReturn(_ textField:UITextField) -> Bool {
        let msg = chatInput.text
        room?.sendChatMsg(msg:msg)
        chatInput.text = nil
        return false
    }
    
    @IBAction func backBtnClicked(_ btn:UIBarButtonItem) {
        self.room?._setChatWindow(view:nil)
        self.resignFirstResponder()
        self.dismiss(animated: true, completion: nil)
    }
    
    func scrollChat() {
        if !self.canScroll || self.room?.messageBuffer.count == 0 {
            return
        }
        
        self.messageView.scrollToRow(at: IndexPath(row: self.room.messageBuffer.count - 1, section: 0),
            at: UITableView.ScrollPosition.bottom, animated: true)
    }
    
    func handleNilSocketURL(_ not:Notification) {
        CytubeUtils.displayGenericAlertWithNoButtons(title: "Connection Failed",
            message: "Could not connect to server, check you are connected to the internet", view: self)
    }
    
    func handleNoInternet(_ not:Notification) {
        CytubeUtils.displayGenericAlertWithNoButtons(title: "No Internet",
            message: "Check your internet connection", view: self)
    }
    
    func handleSocketURLFail(_ not:Notification) {
        CytubeUtils.displayGenericAlertWithNoButtons(title: "Socket Failure", message: "Failed to load socketURL. Check you entered" +
            " the server correctly", view: self)
    }
    
    func handleSocketTimeout(_ not:Notification) {
        CytubeUtils.displayGenericAlertWithNoButtons(title: "Timeout", message: "It is taking too long to connect." +
            "The server may be having trouble, or your connection is poor.", view: self)
    }
    
    func wasKicked(_ not:Notification) {
        let roomName = self.room!.roomName
        let kickObj = not.object as! NSDictionary
        
        if (kickObj["room"] as? String) != roomName {
            return
        }
        
        self.chatInput.resignFirstResponder()
        let reason = kickObj["reason"] as! String
        
        let alert = UIAlertController(title: "Kicked", message:
            "You have been kicked from room \(roomName). Reason: \(reason)", preferredStyle: UIAlertController.Style.alert)
        let action = UIAlertAction(title: "Okay", style: UIAlertAction.Style.default) {action in
            self.room?._setChatWindow(view:nil)
            self.room?.closeRoom()
            self.dismiss(animated: true, completion: nil)
        }
        alert.addAction(action)
        self.present(alert, animated: true, completion: nil)
    }
    
    func passwordFail(_ not:Notification) {
        let roomName = self.room!.roomName
        let alert = UIAlertController(title: "Password Fail", message:
            "No password, or incorrect password for: \(roomName). Please try adding again.",
            preferredStyle: UIAlertController.Style.alert)
        let action = UIAlertAction(title: "Okay", style: UIAlertAction.Style.default) {action in
            self.room?._setChatWindow(view:nil)
            self.dismiss(animated: true, completion: nil)
        }
        alert.addAction(action)
        self.present(alert, animated: true, completion: nil)
        
    }
    
    func alertView(_ alertView: UIAlertView, clickedButtonAt buttonIndex: Int) {
        self.dismiss(animated: true, completion: nil)
    }
}
