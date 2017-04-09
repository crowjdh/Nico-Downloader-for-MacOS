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
    case filtering
    case done
    case error
    
    var description: String {
        switch self {
        case .sleeping:
            return "Sleeping"
        case .fetching:
            return "Fetching"
        case .downloading:
            return "Downloading"
        case .filtering:
            return "Filtering"
        case .done:
            return "Done"
        case .error:
            return "Error"
        }
    }
}

struct FilterItem {
    var videoFileURL: URL? = nil
    var filterFileURL: URL? = nil
    var filterProgress: Double = 0
}

struct NicoItem {
    let videoId: String
    var name: String!
    var pubdate: Date?
    var status: Status = .sleeping
    var apiInfo: [String: String]!
    var videoFileURL: URL!
    var filterFileURL: URL?
    var duration: Double!
    
    var progress: Double = 0
    var filterProgress: Double = 0
    
    var videoFilePath: String! {
        return videoFileURL.absoluteString.removingPercentEncoding
    }
    
    init(videoId: String) {
        self.videoId = videoId
    }
    
    init(videoId: String, name: String, pubdate: Date) {
        self.init(videoId: videoId)
        self.name = name
        self.pubdate = pubdate
    }
}
