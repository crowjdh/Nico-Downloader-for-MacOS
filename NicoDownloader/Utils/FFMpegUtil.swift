//
//  ProcessUtil.swift
//  NicoDownloader
//
//  Created by Jeong on 2017. 3. 3..
//  Copyright © 2017년 Jeong. All rights reserved.
//

import Foundation

typealias ProcessMeta = (Process, DispatchWorkItem)
typealias ProcessResult = ([String], [String], Int32)
typealias VideoResolution = (Int, Int)

func filterVideo(inputFilePath: String, outputFilePath: String,
                 filterPath: String, callback: @escaping (Bool) -> Void) -> (Process, DispatchWorkItem)? {
    let arguments = [
        "-y",
        "-i", inputFilePath,
        "-filter_script:v", filterPath,
        outputFilePath
    ]
    return requestProcess(bundleName: "ffmpeg", arguments: arguments) { processResult in
        callback(processResult.2 == 0)
    }
}

func videoResolution(inputFilePath: String) -> VideoResolution? {
    let arguments = [
        "-v", "error",
        "-show_entries", "stream=width,height",
        "-of", "default=noprint_wrappers=1",
        inputFilePath
    ]
    guard let output = requestProcess(bundleName: "ffprobe", arguments: arguments)?.0, output.count == 2 else {
        return nil
    }
    let widthString = output[0].components(separatedBy: "=")[1]
    let heightString = output[1].components(separatedBy: "=")[1]
    
    guard let width = Int(widthString), let height = Int(heightString) else {
        return nil
    }
    return VideoResolution(width, height)
}

private func requestProcess(bundleName: String, bundleType: String? = nil,
                            arguments: [String]?) -> ProcessResult? {
    var result: ProcessResult? = nil
    let processMeta = createProcessMeta(bundleName: bundleName, bundleType: bundleType, arguments: arguments) {
        result = $0
    }
    guard let process = processMeta?.0, let task = processMeta?.1 else {
        return nil
    }
    task.perform()
    process.waitUntilExit()
    
    return result
}

private func requestProcess(bundleName: String, bundleType: String? = nil,
                    arguments: [String]?, callback: @escaping (ProcessResult) -> Void) -> ProcessMeta? {
    guard let processMeta = createProcessMeta(bundleName: bundleName, bundleType: bundleType, arguments: arguments, callback: callback) else {
        return nil
    }
    DispatchQueue.global(qos: .userInitiated).async(execute: processMeta.1)
    
    return processMeta
}

private func createProcessMeta(bundleName: String, bundleType: String? = nil,
                           arguments: [String]?, callback: @escaping (ProcessResult) -> Void) -> ProcessMeta? {
    guard let launchPath = Bundle.main.path(forResource: bundleName, ofType: bundleType) else {
        return nil
    }
    let process = Process()
    
    var output : [String] = []
    var error : [String] = []
    
    let outpipe = Pipe()
    process.standardOutput = outpipe
    let errpipe = Pipe()
    process.standardError = errpipe
    let task = DispatchWorkItem {
        process.launchPath = launchPath
        process.arguments = arguments
        process.standardInput = FileHandle.nullDevice
        process.launch()
        
        let outdata = outpipe.fileHandleForReading.readDataToEndOfFile()
        if var string = String(data: outdata, encoding: .utf8) {
            string = string.trimmingCharacters(in: .newlines)
            output = string.components(separatedBy: "\n")
        }
        
        let errdata = errpipe.fileHandleForReading.readDataToEndOfFile()
        if var string = String(data: errdata, encoding: .utf8) {
            string = string.trimmingCharacters(in: .newlines)
            error = string.components(separatedBy: "\n")
        }
        process.terminationHandler = { process in
            callback((output, error, process.terminationStatus))
        }
    }
    return (process, task)
}
