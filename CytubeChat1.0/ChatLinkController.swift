//
//  ChatLinkController.swift
//  CytubeChat
//
//  Created by Erik Little on 11/8/14.
//

import UIKit

class ChatLinkController: UIViewController, UIWebViewDelegate {
    
    @IBOutlet weak var webView:UIWebView!
    @IBOutlet weak var navBarTitle:UINavigationItem!
    var link:URL!
    
    @IBAction func backButtonClicked() {
        self.webView.loadHTMLString("", baseURL: nil)
        self.webView = nil
        self.dismiss(animated: true, completion: nil)
    }
    
    override func viewDidLoad() {
        self.navBarTitle.title = self.link.host
        let req = URLRequest(url: self.link)
        self.webView.loadRequest(req)
    }
}
