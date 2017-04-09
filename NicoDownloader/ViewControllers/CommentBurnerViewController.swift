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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        initTableView()
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
    
    private func putURLInFilterItems(url: URL, isVideoURL: Bool) {
        for item in items {
            if item.videoFileURL?.absoluteString == url.absoluteString
                || item.filterFileURL?.absoluteString == url.absoluteString {
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
                if item.filterFileURL == nil {
                    items[idx].filterFileURL = url
                    handled = true
                    break
                }
            }
        }
        if !handled {
            items.append(FilterItem(
                videoFileURL: isVideoURL ? url : nil,
                filterFileURL: isVideoURL ? nil : url,
                filterProgress: 0))
        }
    }
}
