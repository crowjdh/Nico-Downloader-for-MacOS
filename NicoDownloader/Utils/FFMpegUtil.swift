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
                 filterPath: String, callback: @escaping (ProcessResult) -> Void) -> (Process, DispatchWorkItem)? {
    let arguments = [
        "-y",
        "-i", inputFilePath,
        "-filter_script:v", filterPath,
        outputFilePath
    ]
    return requestProcess(bundleName: "ffmpeg", arguments: arguments) { processResult in
        callback(processResult)
    }
}

func getVideoResolution(inputFilePath: String) -> VideoResolution? {
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
    task.wait()
    
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
        
        let errorHandler: (Data) -> Void = { data in
            if let str = String(data: data, encoding: .utf8) {
                if str.contains("Error while decoding stream") {
                    process.interrupt()
                }
            }
        }
        
        var outdata = Data()
        outpipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            outdata.append(data)
            errorHandler(data)
        }
        var errdata = Data()
        errpipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            errdata.append(data)
            errorHandler(data)
        }
        
        process.terminationHandler = { process in
            if var string = String(data: outdata, encoding: .utf8) {
                string = string.trimmingCharacters(in: .newlines)
                output = string.components(separatedBy: "\n")
            }
            if var string = String(data: errdata, encoding: .utf8) {
                string = string.trimmingCharacters(in: .newlines)
                error = string.components(separatedBy: "\n")
            }
            callback((output, error, process.terminationStatus))
        }
        process.launch()
        process.waitUntilExit()
    }
    return (process, task)
}
