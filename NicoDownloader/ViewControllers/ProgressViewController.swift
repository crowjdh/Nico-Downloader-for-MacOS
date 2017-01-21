//
//  ProgressViewController.swift
//  NicoDownloader
//
//  Created by Jeong on 2017. 1. 19..
//  Copyright © 2017년 Jeong. All rights reserved.
//

import Cocoa

import PromiseKit

typealias Callback = () -> Void
typealias BoolCallback = (Bool) -> Void
typealias DoubleCallback = (Double) -> Void
typealias StringCallback = (String) -> Void

enum NicoError: Error {
    case LoginError
    case FetchVideoIdsError(String)
}

class ProgressViewController: NSViewController {
    @IBOutlet weak var downloadProgressTableView: NSTableView!
    
    var account: Account!
    var options: Options!
    var items: [Item] = []
    var sessionManager: Alamofire.SessionManager!
    var cancelled = false
    var downloadRequests: [DownloadRequest] = []
    var downloadWorkItem: DispatchWorkItem?
    var semaphore: DispatchSemaphore?
    
    let cookies = HTTPCookieStorage.shared
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        initTableView()
        initSessionManager()
        
        firstly {
            login()
        }.then {
            self.createItems(fromMylistId: self.options.mylistID)
        }.then{ items -> Void in
            self.items = items
            self.downloadProgressTableView.reloadData()
            self.download()
        }.catch { error in
            print(error)
        }
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        
        view.window?.delegate = self
    }
    
    private func initTableView() {
        downloadProgressTableView.delegate = self
        downloadProgressTableView.dataSource = self
    }
    
    @IBAction func stopAndClose(_ sender: Any) {
        if !cancelled {
            let alert = NSAlert()
            alert.messageText = "Are you sure you want to stop download?"
            alert.addButton(withTitle: "OK")
            alert.addButton(withTitle: "Cancel")
            alert.beginSheetModal(for: view.window!) { response in
                if response == NSAlertFirstButtonReturn {
                    self.cancelled = true
                }
            }
        }
    }
}

extension ProgressViewController: NSWindowDelegate {
    
    func windowDidEndSheet(_ notification: Notification) {
        if cancelled {
            if let downloadWorkItem = self.downloadWorkItem {
                downloadWorkItem.cancel()
            }
            for downloadRequest in self.downloadRequests {
                downloadRequest.cancel()
            }
            dismissViewController(self)
        }
    }
}
