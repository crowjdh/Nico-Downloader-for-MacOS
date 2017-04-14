//
//  CommentBurnerViewController.swift
//  NicoDownloader
//
//  Created by Jeong on 2017. 4. 1..
//  Copyright © 2017년 Jeong. All rights reserved.
//

import Cocoa

class CommentBurnerViewController: NSViewController {

    @IBOutlet weak var videosTableView: NSTableView!
    @IBOutlet weak var filterTableView: NSTableView!
    
    var items: [FilterItem] = []
    weak var selectedTableView: NSTableView?
    var filterProcesses: [Process] = []
    var filterWorkItems: [DispatchWorkItem] = []
    var task: DispatchWorkItem?
    var cancelled = false
    let powerManager = PowerManager()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        initTableView()
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        
        view.window?.delegate = self
    }
    
    private func initTableView() {
        videosTableView.delegate = self
        videosTableView.dataSource = self
        videosTableView.register(forDraggedTypes: [NSGeneralPboard])
        
        filterTableView.delegate = self
        filterTableView.dataSource = self
        filterTableView.register(forDraggedTypes: [NSGeneralPboard])
    }
    
    @IBAction func loadFiles(_ sender: Any) {
        let fileURLs = showOpenPanel { openPanel in
            openPanel.prompt = "Open"
            openPanel.worksWhenModal = true
            openPanel.allowsMultipleSelection = true
            openPanel.canChooseDirectories = true
            openPanel.canChooseFiles = true
            openPanel.resolvesAliases = true
            openPanel.title = "Titlee"
            openPanel.message = "Messageee"
        }
        iterateURLs(fileURLs: fileURLs) { fileURL, isDirectory in
            if !isDirectory {
                if fileURL.pathExtension == "comment" {
                    putURLInFilterItems(url: fileURL, isVideoURL: false)
                } else if fileURL.topLevelMimeType() == "video" {
                    putURLInFilterItems(url: fileURL, isVideoURL: true)
                }
            }
        }
        
        videosTableView.reloadData()
        filterTableView.reloadData()
    }
    @IBAction func applyCommentButtonDidClick(_ sender: Any) {
        startTask()
    }
    
    private func putURLInFilterItems(url: URL, isVideoURL: Bool) {
        for item in items {
            if item.videoFileURL?.absoluteString == url.absoluteString
                || item.commentFileURL?.absoluteString == url.absoluteString {
                return
            }
        }
        var handled = false
        for (idx,item) in items.enumerated() {
            if isVideoURL {
                if item.videoFileURL == nil {
                    items[idx].videoFileURL = url
                    handled = true
                    break
                }
            } else {
                if item.commentFileURL == nil {
                    items[idx].commentFileURL = url
                    handled = true
                    break
                }
            }
        }
        if !handled {
            items.append(FilterItem(
                videoFileURL: isVideoURL ? url : nil,
                commentFileURL: isVideoURL ? nil : url))
        }
    }
}

extension CommentBurnerViewController: NSWindowDelegate {
    
    func windowShouldClose(_ sender: Any) -> Bool {
        if filterProcesses.count == 0 || allDone {
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
        return cancelled
    }
    
    func windowDidEndSheet(_ notification: Notification) {
        if cancelled {
            cancelAllTasksAndDismiss()
        }
    }
    
    func cancelAllTasksAndDismiss() {
        if let task = self.task {
            task.cancel()
        }
        for filterWorkItem in self.filterWorkItems {
            filterWorkItem.cancel()
        }
        for filterProcess in self.filterProcesses {
            filterProcess.interrupt()
        }
        self.view.window?.close()
    }
}
