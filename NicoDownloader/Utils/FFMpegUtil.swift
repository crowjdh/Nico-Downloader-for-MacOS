//
//  ProcessUtil.swift
//  NicoDownloader
//
//  Created by Jeong on 2017. 3. 3..
//  Copyright © 2017년 Jeong. All rights reserved.
//

import Foundation

func filterVideo(inputFilePath: String, outputFilePath: String,
                 filterPath: String, callback: @escaping (Bool) -> Void) -> (Process, DispatchWorkItem)? {
    guard let launchPath = Bundle.main.path(forResource: "ffmpeg", ofType: "") else {
        return nil
    }
    let process = Process()
    let task = DispatchWorkItem {
        process.launchPath = launchPath
        process.arguments = [
            "-y",
            "-i", inputFilePath,
            "-filter_script:v", filterPath,
            outputFilePath
        ]
        process.standardInput = FileHandle.nullDevice
        process.launch()
        process.terminationHandler = { process in
            callback(process.terminationStatus == 0)
        }
    }
    DispatchQueue.global(qos: .userInitiated).async(execute: task)
    
    return (process, task)
}
