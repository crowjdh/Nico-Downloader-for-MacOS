//
//  ProgressTableCellView.swift
//  FileViewer
//
//  Created by Jeong on 2017. 1. 19..
//  Copyright © 2017년 razeware. All rights reserved.
//

import Cocoa

class ProgressTableCellView: NSTableCellView {

    @IBOutlet weak var progressIndicator: NSProgressIndicator!
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Drawing code here.
    }
    
}
