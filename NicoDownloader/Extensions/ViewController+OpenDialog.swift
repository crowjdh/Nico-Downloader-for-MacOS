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
        return showOpenPanel { openPanel in
            openPanel.prompt = "Open"
            openPanel.worksWhenModal = true
            openPanel.allowsMultipleSelection = false
            openPanel.canChooseDirectories = true
            openPanel.canChooseFiles = false
            openPanel.resolvesAliases = true
            openPanel.title = "Titlee"
            openPanel.message = "Messageee"
        }.first
    }
}
