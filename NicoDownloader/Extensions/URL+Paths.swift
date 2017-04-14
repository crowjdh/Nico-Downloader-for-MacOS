//
//  URL+Paths.swift
//  NicoDownloader
//
//  Created by Jeong on 2017. 4. 9..
//  Copyright © 2017년 Jeong. All rights reserved.
//

import Foundation

extension URL {
    var commentedRootURL: URL {
        get {
            return deletingLastPathComponent().appendingPathComponent("Commented", isDirectory: true)
        }
    }
    var filterFileRootURL: URL {
        get {
            return commentedRootURL.appendingPathComponent("filters", isDirectory: true)
        }
    }
    var commentedVideoURL: URL {
        get {
            return commentedRootURL.appendingPathComponent(lastPathComponent)
        }
    }
    var commentFileURL: URL {
        get {
            return filterFileRootURL.appendingPathComponent(deletingPathExtension().lastPathComponent).appendingPathExtension(".comment")
        }
    }
    var filterFileURL: URL {
        get {
            return filterFileRootURL.appendingPathComponent(deletingPathExtension().lastPathComponent).appendingPathExtension(".filter")
        }
    }
}
