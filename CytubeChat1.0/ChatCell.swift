//
//  ChatCell.swift
//  CytubeChat
//
//  Created by Erik Little on 11/8/14.
//

import UIKit

class ChatCell: UITableViewCell, UITextViewDelegate {
    var link:URL!
    
    func textView(_ textView:UITextView, shouldInteractWith URL:URL, in characterRange:NSRange) -> Bool {
        self.link = URL
        ((self.superview!.superview! as! UITableView).dataSource as! ChatWindowController)
            .performSegue(withIdentifier: "openChatLink", sender: self)
        return false
    }
}
