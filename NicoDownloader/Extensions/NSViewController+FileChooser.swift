//
//  NSViewController+FileChooser.swift
//  NicoDownloader
//
//  Created by Jeong on 2017. 4. 1..
//  Copyright © 2017년 Jeong. All rights reserved.
//

import Cocoa

extension NSViewController {
    
    func showOpenPanel(config: (NSOpenPanel) -> Void) -> [URL] {
        let openPanel = NSOpenPanel()
        config(openPanel)
        
        return openPanel.runModal() == NSFileHandlingPanelOKButton ? openPanel.urls : []
    }
    
    func iterateURLs(fileURLs: [URL], callback: (URL, Bool) -> Void) {
        for fileURL in fileURLs {
            let resourceKeys : [URLResourceKey] = [.isDirectoryKey]
            if fileURL.hasDirectoryPath,
                let enumerator = FileManager.default.enumerator(at: fileURL, includingPropertiesForKeys: resourceKeys) {
                for case let fileURL as URL in enumerator {
                    let resourceValues = try! fileURL.resourceValues(forKeys: Set(resourceKeys))
                    callback(fileURL, resourceValues.isDirectory!)
                }
            } else {
                callback(fileURL, false)
            }
        }
    }
}
