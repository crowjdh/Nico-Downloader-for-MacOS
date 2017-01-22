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
    @IBOutlet weak var selectedDirectoryTextField: NSTextField!
    @IBOutlet weak var mylistIdField: NSTextField!
    @IBOutlet weak var rangeTextField: NSTextField!
    @IBOutlet weak var startDownloadButton: NSButton!
    @IBOutlet weak var rememberAccountCheckbox: NSButton!
    
    var sessionManager: SessionManager!
    var saveDirectory: URL?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let keychain = Keychain()
        if let item = keychain.allItems().first, let savedEmail = item["key"] as? String, let password = keychain[savedEmail] {
            emailField.stringValue = savedEmail
            passwordField.stringValue = password
        }
        
        
        if let saveDirectory = UserDefaults.standard.url(forKey: "saveDirectory") {
            setSaveDirectory(url: saveDirectory)
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
        
        let rangeComponenets = rangeTextField.stringValue.components(separatedBy: ":")
        if rangeComponenets.count == 2, let from = Int(rangeComponenets[0]), let to = Int(rangeComponenets[1]), from <= to {
            dest.options.range = max((from - 1), 1)...(to - 1)
        }
        if let saveDirectory = saveDirectory {
            dest.options.saveDirectory = saveDirectory
        }
    }
    
    @IBAction func chooseDirectoryButtonDidTap(_ sender: Any) {
        if let directoryUrl = showSaveDirectoryChooser() {
            setSaveDirectory(url: directoryUrl)
            UserDefaults.standard.set(saveDirectory, forKey: "saveDirectory")
        }
    }
    
    private func setSaveDirectory(url: URL) {
        saveDirectory = url
        selectedDirectoryTextField.stringValue = url.path
    }
}

