//
//  Item.swift
//  NicoDownloader
//
//  Created by Jeong on 2017. 1. 19..
//  Copyright © 2017년 Jeong. All rights reserved.
//

import Foundation
import SwiftyJSON

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
    var commentFileURL: URL? = nil
    var filterFileURL: URL? = nil
    var videoDuration: Double!
    var filterProgress: Double = 0
    var status: Status = .sleeping
    
    init(videoFileURL: URL?, commentFileURL: URL?) {
        self.videoFileURL = videoFileURL
        self.commentFileURL = commentFileURL
    }
    
    var videoFilePath: String? {
        return videoFileURL?.absoluteString.removingPercentEncoding
    }
}

protocol NicoItem {
    var name: String! { get set }
    var status: Status { get set }
    var apiInfo: [String: String]! { get set }
    var videoFileURL: URL! { get set }
    var filterFileURL: URL? { get set }
    var duration: Double! { get set }
    
    var progress: Double { get set }
    var filterProgress: Double { get set }
}

extension NicoItem {
    var videoFilePath: String! {
        return videoFileURL.absoluteString.removingPercentEncoding
    }
}

class NicoVideoItem: NicoItem {
    let videoId: String
    var name: String!
    var pubdate: Date?
    var status: Status = .sleeping
    // XXX: Deprecated
    var apiInfo: [String: String]!
    var apiDataJson: JSON!
    var videoFileURL: URL!
    var filterFileURL: URL?
    var duration: Double!
    
    var progress: Double = 0
    var filterProgress: Double = 0
    
    init(videoId: String) {
        self.videoId = videoId
    }
    
    convenience init(videoId: String, name: String, pubdate: Date) {
        self.init(videoId: videoId)
        self.name = name
        self.pubdate = pubdate
    }
}

class NicoNamaItem: NicoItem {
    let videoId: String
    var name: String!
    var status: Status = .sleeping
    var apiInfo: [String: String]!
    var videoFileURL: URL!
    var filterFileURL: URL?
    var duration: Double!
    
    var progress: Double = 0
    var filterProgress: Double = 0
    
    init(videoId: String) {
        self.videoId = videoId
    }
}
