//
//  String+UnicodeScalar.swift
//  NicoDownloader
//
//  Created by Jeong on 2017. 3. 24..
//  Copyright © 2017년 Jeong. All rights reserved.
//

import Foundation

extension String {
    var unicodeScalar: UnicodeScalar {
        get {
            return unicodeScalars[unicodeScalars.startIndex]
        }
    }
}
