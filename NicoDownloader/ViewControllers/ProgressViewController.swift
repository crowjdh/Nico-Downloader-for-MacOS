//
//  ProgressViewController.swift
//  NicoDownloader
//
//  Created by Jeong on 2017. 1. 19..
//  Copyright © 2017년 Jeong. All rights reserved.
//

import Cocoa

import PromiseKit

enum NicoError: Error {
    case LoginError
    case FetchVideoIdsError(String)
    case Cancelled
    case UnknownError(String)
}

class ProgressViewController: NSViewController {
    @IBOutlet weak var downloadProgressTableView: NSTableView!
    @IBOutlet weak var messageLabel: NSTextField!
    
    var account: Account!
    var options: Options!
    var items: [Item] = []
    var sessionManager: Alamofire.SessionManager!
    var cancelled = false
    var downloadRequests: [DownloadRequest] = []
    var downloadWorkItem: DispatchWorkItem?
    var semaphore: DispatchSemaphore?
    var allDone: Bool {
        get {
            return self.items.reduce(true) { $0.0 && ($0.1.status == .done) }
        }
    }
    
    let cookies = HTTPCookieStorage.shared
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        initTableView()
        initSessionManager()
        
        firstly {
            login()
        }.then { () -> Promise<Array<Item>> in
            switch self.options.videoInfo {
            case let mylist as Mylist:
                return self.createItems(fromMylist: mylist)
            case let videos as Videos:
                return Promise<Array<Item>>(value: videos.ids.map { Item(videoId: $0) })
            default:
                throw NicoError.UnknownError("Invalid videoInfo.")
            }
        }.then{ items -> Void in
            self.items = items
            self.downloadProgressTableView.reloadData()
            self.download()
        }.catch { error in
            var msg: String
            switch error {
            case NicoError.LoginError:
                msg = "Login error. Check id/pw and retry."
            case NicoError.FetchVideoIdsError(let errMsg):
                msg = errMsg
            case NicoError.Cancelled:
                msg = "Cancelled"
            default:
                msg = "Unknown error occurred."
            }
            self.updateStatusMessage(message: msg)
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
        if downloadRequests.count == 0 || allDone {
            cancelled = true
            cancelAllTasksAndDismiss()
        } else if !cancelled {
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
    
    func updateStatusMessage(message: String) {
        messageLabel.stringValue = message
    }
}

extension ProgressViewController: NSWindowDelegate {
    
    func windowDidEndSheet(_ notification: Notification) {
        if cancelled {
            cancelAllTasksAndDismiss()
        }
    }
    
    func cancelAllTasksAndDismiss() {
        if let downloadWorkItem = self.downloadWorkItem {
            downloadWorkItem.cancel()
        }
        for downloadRequest in self.downloadRequests {
            downloadRequest.cancel()
        }
        dismissViewController(self)
    }
}
