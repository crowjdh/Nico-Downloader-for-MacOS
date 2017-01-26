//
//  ViewController+OpenDialog.swift
//  NicoDownloader
//
//  Created by Jeong on 2017. 1. 22..
//  Copyright © 2017년 Jeong. All rights reserved.
//

import Foundation
import Cocoa

extension ViewController {
    
    func showSaveDirectoryChooser() -> URL? {
        let myFiledialog = NSOpenPanel()
        
        myFiledialog.prompt = "Open"
        myFiledialog.worksWhenModal = true
        myFiledialog.allowsMultipleSelection = false
        myFiledialog.canChooseDirectories = true
        myFiledialog.canChooseFiles = false
        myFiledialog.resolvesAliases = true
        myFiledialog.title = "Titlee"
        myFiledialog.message = "Messageee"
        
        let directorySelected = myFiledialog.runModal() == NSFileHandlingPanelOKButton
        
        return directorySelected ? myFiledialog.url : nil
    }
}
