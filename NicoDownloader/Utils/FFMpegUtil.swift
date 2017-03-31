//
//  ProcessUtil.swift
//  NicoDownloader
//
//  Created by Jeong on 2017. 3. 3..
//  Copyright © 2017년 Jeong. All rights reserved.
//

import Foundation

typealias ProcessMeta = (Process, DispatchWorkItem)
typealias ProgressCallback = (String) -> Void
typealias ProcessResult = ([String], [String], Int32)
typealias VideoResolution = (Int, Int)

func filterVideo(inputFilePath: String, outputFilePath: String,
                 filterPath: String, progressCallback: ProgressCallback? = nil,
                 callback: @escaping (ProcessResult) -> Void) -> (Process, DispatchWorkItem)? {
    let arguments = [
        "-y",
        "-i", inputFilePath,
        "-filter_script:v", filterPath,
        "-vcodec", "h264",
        outputFilePath
    ]
    return requestProcess(bundleName: "ffmpeg", arguments: arguments,
                          progressCallback: progressCallback) { processResult in
        callback(processResult)
    }
}

// TODO: Consider force unwrapping return value
func getVideoResolution(inputFilePath: String) -> VideoResolution? {
    guard let output = probe(inputFilePath: inputFilePath) else {
        return nil
    }
    let widthString = output[0].components(separatedBy: "=")[1]
    let heightString = output[1].components(separatedBy: "=")[1]
    
    guard let width = Int(widthString), let height = Int(heightString) else {
        return nil
    }
    return VideoResolution(width, height)
}

func getVideoDuration(inputFilePath: String) -> Double! {
    let duration = probe(inputFilePath: inputFilePath)![2].components(separatedBy: "=")[1]
    return Double(duration)
}

func probe(inputFilePath: String) -> [String]? {
    let arguments = [
        "-v", "error",
        "-select_streams", "v:0",
        "-v", "error",
        "-show_entries", "stream=width,height,duration",
        "-of", "default=noprint_wrappers=1",
        inputFilePath
    ]
    guard let output = requestProcess(bundleName: "ffprobe", arguments: arguments)?.0, output.count == 3 else {
        return nil
    }
    return output
}

func encodedTime(fromOutput output: String) -> Double? {
    let pattern = "\\d\\d:\\d\\d:\\d\\d.\\d\\d"
    guard let range = output.range(of: pattern, options: .regularExpression) else {
        return nil
    }
    let timeComponents = output.substring(with: range).components(separatedBy: ":")
    return Double(timeComponents[0])! * 60 * 60 + Double(timeComponents[1])! * 60 + Double(timeComponents[2])!
}

private func requestProcess(bundleName: String, bundleType: String? = nil,
                            arguments: [String]?) -> ProcessResult? {
    var result: ProcessResult? = nil
    let processMeta = createProcessMeta(bundleName: bundleName, bundleType: bundleType, arguments: arguments) {
        result = $0
    }
    guard let _ = processMeta?.0, let task = processMeta?.1 else {
        return nil
    }
    task.perform()
    task.wait()
    
    return result
}

private func requestProcess(bundleName: String, bundleType: String? = nil,
                            arguments: [String]?,
                            progressCallback: ProgressCallback? = nil,
                            callback: @escaping (ProcessResult) -> Void) -> ProcessMeta? {
    guard let processMeta = createProcessMeta(bundleName: bundleName, bundleType: bundleType, arguments: arguments, progressCallback: progressCallback, callback: callback) else {
        return nil
    }
    DispatchQueue.global(qos: .userInitiated).async(execute: processMeta.1)
    
    return processMeta
}

private func createProcessMeta(bundleName: String, bundleType: String? = nil,
                               arguments: [String]?, progressCallback: ProgressCallback? = nil,
                               callback: @escaping (ProcessResult) -> Void) -> ProcessMeta? {
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
                print(str)
                if str.contains("Error while decoding stream") {
                    process.interrupt()
                }
            }
        }
        
        var outdata = Data()
        outpipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            outdata.append(data)
            if let msg = String(data: data, encoding: .utf8) {
                progressCallback?(msg)
            }
            errorHandler(data)
        }
        var errdata = Data()
        errpipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            errdata.append(data)
            if let msg = String(data: data, encoding: .utf8) {
                progressCallback?(msg)
            }
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
