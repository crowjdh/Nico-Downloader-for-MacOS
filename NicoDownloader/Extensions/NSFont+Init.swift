//
//  NSFont+Init.swift
//  NicoDownloader
//
//  Created by Jeong on 2017. 3. 24..
//  Copyright © 2017년 Jeong. All rights reserved.
//

import Foundation
import Cocoa

extension NSFont {
    convenience init(name: String, fontSize: Float) {
        self.init(name: name, size: CGFloat(fontSize))!
    }
}
