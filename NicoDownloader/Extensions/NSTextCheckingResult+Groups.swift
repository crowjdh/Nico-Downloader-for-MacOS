//
//  NSTextCheckingResult+Groups.swift
//  NicoDownloader
//
//  Created by Jeong on 10/10/2018.
//  Copyright © 2018 Jeong. All rights reserved.
//

import Foundation

extension NSTextCheckingResult {
    func groups(src: String) -> [String?] {
        var groups = [String?]()
        for i in  0 ..< self.numberOfRanges {
            let group = String(src[Range(self.range(at: i), in: src)!])
            groups.append(group)
        }
        return groups
    }
}
