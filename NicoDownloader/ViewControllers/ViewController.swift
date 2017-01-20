//
//  ViewController.swift
//  NicoDownloader
//
//  Created by Jeong on 2017. 1. 19..
//  Copyright © 2017년 Jeong. All rights reserved.
//

import Cocoa
import Alamofire

class ViewController: NSViewController {

    @IBOutlet weak var emailField: NSTextField!
    @IBOutlet weak var passwordField: NSSecureTextField!
    
    var sessionManager: SessionManager!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
//        let configuration = URLSessionConfiguration.default
//        sessionManager = Alamofire.SessionManager(configuration: configuration)
//        let videoApiUrl = "http://flapi.nicovideo.jp/api/getflv/sm26693090?as3=1"
//        sessionManager.request(videoApiUrl).responseString { response in
//            guard let htmlString = response.result.value else {
//                return
//            }
//            let url = htmlString.components(separatedBy: "&")
//                .map { $0.components(separatedBy: "=") }
//                .filter { $0[0] == "url" }
//                .map { $0[1] }[0]
//            print(url)
//        }
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }
    
    override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
        guard let segID = segue.identifier, segID == "showDownloadController", let dest = segue.destinationController as? ProgressViewController else {
            return
        }
        
        dest.account = Account(email: emailField.stringValue, password: passwordField.stringValue)
    }

}

