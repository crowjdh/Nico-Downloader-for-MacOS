//
//  Item.swift
//  NicoDownloader
//
//  Created by Jeong on 2017. 1. 19..
//  Copyright © 2017년 Jeong. All rights reserved.
//

import Foundation

struct Item {
    let videoId: String
    let name: String
    let pubdate: Date
    
    var progress: Double = 0
    
    init(videoId: String, name: String, pubdate: Date) {
        self.videoId = videoId
        self.name = name
        self.pubdate = pubdate
    }
}
