//
//  Account.swift
//  NicoDownloader
//
//  Created by Jeong on 2017. 1. 19..
//  Copyright © 2017년 Jeong. All rights reserved.
//

import Foundation

struct Account {
    let email: String
    let password: String
}

struct Options {
    let videoInfo: VideoInfo
    var saveDirectory: URL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]
    
    init(videoInfo: VideoInfo) {
        self.videoInfo = videoInfo
    }
}

protocol VideoInfo {}

struct Mylist: VideoInfo {
    let id: String
    var range: ClosedRange<Int>? = nil
    
    init(id: String) {
        self.id = id
    }
    
    init(id: String, range: ClosedRange<Int>?) {
        self.init(id: id)
        self.range = range
    }
}

struct Videos: VideoInfo {
    let ids: [String]
}
