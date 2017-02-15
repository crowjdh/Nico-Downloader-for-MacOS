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
    @IBOutlet weak var modeTabView: NSTabView!
    @IBOutlet weak var videoIdsTextField: NSTextField!
    @IBOutlet weak var advancedOptionsBox: NSBox!
    @IBOutlet weak var advancedOptionsDisclosure: NSButton!
    @IBOutlet weak var advancedOptionHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var concurrentDownloadCountButton: NSPopUpButton!
    
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
        
        toggleAdvancedOptions(animate: false)
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
        guard let segID = segue.identifier, segID == "showDownloadController",
            let dest = segue.destinationController as? ProgressViewController,
            let options = createOptions() else {
                return
        }
        
        let account = Account(email: emailField.stringValue, password: passwordField.stringValue)
        if rememberAccountCheckbox.state == NSOnState {
            let keychain = Keychain()
            try? keychain.removeAll()
            keychain[account.email] = account.password
        }
        
        dest.account = account
        dest.options = options
    }
    
    @IBAction func chooseDirectoryButtonDidTap(_ sender: Any) {
        if let directoryUrl = showSaveDirectoryChooser() {
            setSaveDirectory(url: directoryUrl)
            UserDefaults.standard.set(saveDirectory, forKey: "saveDirectory")
        }
    }
    
    private func createOptions() -> Options? {
        let videoInfo: VideoInfo
        switch modeTabView.selectedTabViewItem?.label {
        case .some("Video"):
            videoInfo = Videos(ids: videoIdsTextField.stringValue.components(separatedBy: " "))
        default:
            var mylist = Mylist(id: mylistIdField.stringValue)
            let rangeComponenets = rangeTextField.stringValue.components(separatedBy: ":")
            if rangeComponenets.count == 2, let from = Int(rangeComponenets[0]), let to = Int(rangeComponenets[1]), from <= to {
                mylist.range = max((from - 1), 0)...(to - 1)
            }
            videoInfo = mylist
        }
        guard let concurrentDownloadCountString = concurrentDownloadCountButton.selectedItem?.title,
            let concurrentDownloadCount = Int(concurrentDownloadCountString) else {
                return nil
        }
        
        var options = Options(videoInfo: videoInfo, concurrentDownloadCount: concurrentDownloadCount)
        
        if let saveDirectory = saveDirectory {
            options.saveDirectory = saveDirectory
        }
        
        return options
    }
    
    private func setSaveDirectory(url: URL) {
        saveDirectory = url
        selectedDirectoryTextField.stringValue = url.path
    }
    
    @IBAction func advancedOptionsDidClick(_ sender: Any) {
        toggleAdvancedOptions()
    }
    
    private func toggleAdvancedOptions(animate: Bool = true) {
        let show = advancedOptionHeightConstraint.constant == 0
        let constraint = animate ? advancedOptionHeightConstraint.animator() : advancedOptionHeightConstraint
        let box = animate ? advancedOptionsBox.animator() : advancedOptionsBox
        let disclosure = animate ? advancedOptionsDisclosure.animator() : advancedOptionsDisclosure
        
        constraint!.constant = show ? 34 : 0
        box!.isHidden = !show
        disclosure!.state = show ? NSOnState : NSOffState
    }
}

