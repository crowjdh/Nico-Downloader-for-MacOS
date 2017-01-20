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
    @IBOutlet weak var mylistIdField: NSTextField!
    @IBOutlet weak var startDownloadButton: NSButton!
    
    var sessionManager: SessionManager!
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
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
        dest.options = Options(mylistID: mylistIdField.stringValue)
    }

}

