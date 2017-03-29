//
//  TestUtil.swift
//  NicoDownloader
//
//  Created by Jeong on 2017. 3. 28..
//  Copyright © 2017년 Jeong. All rights reserved.
//

import Foundation

func measurePerformanceOrThrow(_ name:String, _ operation: () throws -> Void) throws {
    let startTime = CFAbsoluteTimeGetCurrent()
    try operation()
    let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
    print("Time elapsed for \(name): \(timeElapsed) s")
}

func measurePerformance(_ name:String, _ operation: () -> Void) {
    try! measurePerformanceOrThrow(name, operation)
}
