//
//  ViewController.swift
//  NicoDownloader
//
//  Created by Jeong on 2017. 1. 19..
//  Copyright © 2017년 Jeong. All rights reserved.
//

import Cocoa
import Alamofire
import KeychainAccess

class ViewController: NSViewController {

    @IBOutlet weak var emailField: NSTextField!
    @IBOutlet weak var passwordField: NSSecureTextField!
    @IBOutlet weak var mylistIdField: NSTextField!
    @IBOutlet weak var startDownloadButton: NSButton!
    @IBOutlet weak var rememberAccountCheckbox: NSButton!
    
    var sessionManager: SessionManager!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let keychain = Keychain()
        if let item = keychain.allItems().first, let savedEmail = item["key"] as? String, let password = keychain[savedEmail] {
            emailField.stringValue = savedEmail
            passwordField.stringValue = password
        }
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
        
        let account = Account(email: emailField.stringValue, password: passwordField.stringValue)
        if rememberAccountCheckbox.state == NSOnState {
            let keychain = Keychain()
            try? keychain.removeAll()
            keychain[account.email] = account.password
        }
        
        dest.account = account
        dest.options = Options(mylistID: mylistIdField.stringValue)
    }

}

