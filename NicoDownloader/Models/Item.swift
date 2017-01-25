//
//  Item.swift
//  NicoDownloader
//
//  Created by Jeong on 2017. 1. 19..
//  Copyright © 2017년 Jeong. All rights reserved.
//

import Foundation

enum Status {
    case sleeping
    case fetching
    case downloading
    case done
    
    var description: String {
        switch self {
        case .sleeping:
            return "Sleeping"
        case .fetching:
            return "Fetching"
        case .downloading:
            return "Downloading"
        case .done:
            return "Done"
        }
    }
}

struct Item {
    let videoId: String
    var name: String
    var pubdate: Date?
    var status: Status = .sleeping
    
    var progress: Double = 0
    
    init(videoId: String) {
        self.videoId = videoId
        self.name = "Unknown"
    }
    
    init(videoId: String, name: String, pubdate: Date) {
        self.init(videoId: videoId)
        self.name = name
        self.pubdate = pubdate
    }
}
