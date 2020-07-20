//
//  LoginController.swift
//  CytubeChat
//
//  Created by Erik Little on 10/16/14.
//

import UIKit

class LoginController: UIViewController, UITextFieldDelegate {
    
    @IBOutlet weak var usernameText:UITextField!
    @IBOutlet weak var passwordText:UITextField!
    @IBOutlet weak var rememberSwitch:UISwitch!
    var room:CytubeRoom?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.room = roomMng.getActiveRoom()
        if !UserDefaults.standard.bool(forKey: "HasLoggedIn") {
            CytubeUtils.displayGenericAlertWithNoButtons(title: "Hint",
                message: "You can login as guest by submitting a username without a password.",
                view: self)
        }
        
        if let (username, password) = dbManger?.getUsernamePasswordForChannel(server: room!.server!,
            channel: room!.roomName) {
                self.usernameText.text = username
                self.passwordText.text = password
        }
    }
    
    @IBAction func backBtnClicked(_ btn:UIBarButtonItem) {
        self.resignFirstResponder()
        self.dismiss(animated: true, completion: nil)
    }
    
    @IBAction func submitBtnClicked(_ btn:UIBarButtonItem) {
        self.resignFirstResponder()
        self.handleLogin()
    }
    
    func handleLogin() {
        if self.usernameText.text == "" {
            CytubeUtils.displayGenericAlertWithNoButtons(title: "Invalid Username",
                message: "Username cannot be blank",
                view: self)
            return
        }
        
        self.room?.username = self.usernameText.text
        self.room?.password = self.passwordText.text
        self.room?.sendLogin()
        
        if self.rememberSwitch.isOn && self.passwordText.text != "" {
            self.room?.saveUser()
        } else {
            self.room?.forgetUser()
        }
        
        self.dismiss(animated: true, completion: nil)
        UserDefaults.standard.set(true, forKey: "HasLoggedIn")
        UserDefaults.standard.synchronize()
    }
    
    func textFieldShouldReturn(_ textField:UITextField) -> Bool {
        let nextTag = textField.tag + 1
        let nextResponder = textField.superview?.viewWithTag(nextTag)
        if nextResponder != nil {
            nextResponder!.becomeFirstResponder()
            return false
        }
        
        textField.resignFirstResponder()
        self.handleLogin()
        return true
    }
}
