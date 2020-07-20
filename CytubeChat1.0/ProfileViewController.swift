//
//  ProfileViewController.swift
//  CytubeChat
//
//  Created by Erik Little on 12/20/14.
//

import UIKit
import ImageIO

class ProfileViewController: UIViewController {
    @IBOutlet weak var backBtn:UIBarButtonItem!
    @IBOutlet weak var navBarTitle:UINavigationItem!
    @IBOutlet weak var profileImageView:UIImageView!
    @IBOutlet weak var profileNavBar:UINavigationBar!
    @IBOutlet weak var profileTextView:UITextView!
    var user:CytubeUser?
    
    override func viewDidLoad() {
        if user == nil {
            self.dismiss(animated: true, completion: nil)
            return
        }
        
        navBarTitle.title = self.user?.username
        profileTextView.text = self.user?.profileText
        
        if user?.profileImage == nil {
            return
        }
        
        let urlString = user!.profileImage!.absoluteString
        
        URLSession.shared.dataTask(with: URLRequest(url: user!.profileImage!), completionHandler: {[weak self] data, res, err in
            if err != nil || self == nil || data == nil {
                return
            }
            
            DispatchQueue.main.async {
                // Image is a GIF
                if urlString[".gif$"].matches().count != 0 {
                    let source = CGImageSourceCreateWithData(data! as CFData, nil)!
                    var images = [UIImage]()
                    var dur = 0.0
                    
                    for i in 0..<CGImageSourceGetCount(source) {
                        let asCGImage = CGImageSourceCreateImageAtIndex(source, i, nil)
                        let prop = CGImageSourceCopyPropertiesAtIndex(source, i, nil)
                        
                        // Get delay for each frame, so we can play back at proper speed
                        if let gif = (prop as? NSDictionary)?["{GIF}"] as? NSDictionary {
                            if let delay = gif["UnclampedDelayTime"] as? Double {
                                dur += delay
                            }
                        }
                        images.append(UIImage(cgImage: asCGImage!))
                    }
                    
                    self?.profileImageView.animationImages = images
                    self?.profileImageView.animationDuration = dur
                    self?.profileImageView.startAnimating()
                } else {
                    self?.profileImageView.image = UIImage(data: data!)
                    self?.profileImageView.contentMode = UIView.ContentMode.scaleAspectFit
                }
            }
            }) .resume()
    }
    
    @IBAction func backBtnClicked(_ btn:UIBarButtonItem) {
        dismiss(animated: true, completion: nil)
    }
}
