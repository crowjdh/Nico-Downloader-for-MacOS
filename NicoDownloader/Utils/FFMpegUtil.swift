//
//  ProcessUtil.swift
//  NicoDownloader
//
//  Created by Jeong on 2017. 3. 3..
//  Copyright © 2017년 Jeong. All rights reserved.
//

import Foundation

typealias ProgressCallback = (String) -> Void
typealias ProcessResult = ([String], [String], Int32)
typealias VideoResolution = (Int, Int)

fileprivate let probeUnavailable = "N/A"

func filterVideo(inputFilePath: String, outputFilePath: String,
                 filterPath: String, progressCallback: ProgressCallback? = nil,
                 callback: @escaping (ProcessResult) -> Void) -> Process? {
    let arguments = [
        "-y",
        "-i", inputFilePath,
        "-filter_script:v", filterPath,
        "-vcodec", "h264",
        "-acodec", "copy",
        outputFilePath
    ]
    return requestProcess(bundleName: "ffmpeg", arguments: arguments,
                          progressCallback: progressCallback) { processResult in
        callback(processResult)
    }
}

func concatVideos(inputFilesUrl: URL, fileExtension: String, outputFileURL: URL,
                 callback: @escaping (ProcessResult) -> Void) -> Process? {
    let concatInputFileName = "concat_input_file.txt"
    let concatInputFilePath = inputFilesUrl.appendingPathComponent(concatInputFileName)
    try? FileManager.default.contentsOfDirectory(at: inputFilesUrl, includingPropertiesForKeys: nil)
        .filter { $0.pathExtension == fileExtension }
        .sorted(by: { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending })
        .map { (inputFileUrl: URL) -> String in
            return "file '\(inputFileUrl.path)'"
        }
        .joined(separator: "\n")
        .write(to: concatInputFilePath, atomically: true, encoding: .utf8)
    let arguments = [
        "-f", "concat",
        "-safe", "0",
        "-i", "\(concatInputFilePath.path)",
        "-c", "copy",
        outputFileURL.path
    ]
    return requestProcess(bundleName: "ffmpeg", arguments: arguments) { processResult in
        callback(processResult)
        try? FileManager.default.removeItem(at: concatInputFilePath)
    }
}

func rtmpdump(withArguments arguments: [String], progressCallback: ProgressCallback? = nil,
              callback: @escaping (ProcessResult) -> Void) -> Process? {
    return requestProcess(bundleName: "rtmpdump", arguments: arguments,
                          progressCallback: progressCallback) { processResult in
        callback(processResult)
    }
}

// TODO: Consider force unwrapping return value
func getVideoResolution(inputFilePath: String) -> VideoResolution? {
    let arguments = [
        "-v", "error",
        "-select_streams", "v:0",
        "-show_entries", "stream=width,height",
        "-of", "default=noprint_wrappers=1",
        inputFilePath
    ]
    guard let output = requestProcess(bundleName: "ffprobe", arguments: arguments)?.0,
          output.count >= 2,
          output[0] != probeUnavailable, output[1] != probeUnavailable else {
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
    let arguments = [
        "-v", "error",
        "-select_streams", "v:0",
        "-show_entries", "format=duration",
        "-of", "default=noprint_wrappers=1",
        inputFilePath
    ]
    guard let output = requestProcess(bundleName: "ffprobe", arguments: arguments)?.0,
        output.count == 1, output[0] != probeUnavailable else {
        return nil
    }
    let duration = output[0].components(separatedBy: "=")[1]
    return Double(duration)
}

func encodedTime(fromOutput output: String) -> Double? {
    let pattern = "\\d\\d:\\d\\d:\\d\\d.\\d\\d"
    guard let range = output.range(of: pattern, options: .regularExpression) else {
        return nil
    }
    let timeComponents = output.substring(with: range).components(separatedBy: ":")
    return Double(timeComponents[0])! * 60 * 60 + Double(timeComponents[1])! * 60 + Double(timeComponents[2])!
}

func encodePercentage(fromOutput output: String) -> Double? {
    let pattern = "\\((.*)%\\)"
    guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
        let firstMatch = regex.firstMatch(in: output, options: [], range: NSRange(output.startIndex..., in: output)) else {
        return nil
    }
    let groups = firstMatch.groups(src: output)
    guard groups.count > 1, let progress = groups[1] else {
        return nil
    }
    
    return Double(progress)
}

private func requestProcess(bundleName: String, bundleType: String? = nil,
                            arguments: [String]?) -> ProcessResult? {
    var result: ProcessResult? = nil
    let process = createProcess(bundleName: bundleName, bundleType: bundleType, arguments: arguments) {
        result = $0
    }
    guard process != nil else {
        return nil
    }
    process!.launch()
    while true {
        process!.waitUntilExit()
        
        if result != nil {
            break
        }
        usleep(100)
    }
    
    return result
}

private func requestProcess(bundleName: String, bundleType: String? = nil,
                            arguments: [String]?,
                            progressCallback: ProgressCallback? = nil,
                            callback: @escaping (ProcessResult) -> Void) -> Process? {
    guard let process = createProcess(bundleName: bundleName, bundleType: bundleType, arguments: arguments, progressCallback: progressCallback, callback: callback) else {
        return nil
    }
    process.launch()
    
    return process
}

private func createProcess(bundleName: String, bundleType: String? = nil,
                               arguments: [String]?, progressCallback: ProgressCallback? = nil,
                               callback: @escaping (ProcessResult) -> Void) -> Process? {
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
    process.launchPath = launchPath
    process.arguments = arguments
    process.standardInput = FileHandle.nullDevice
    
    let errorHandler: (Data) -> Void = { data in
        if let str = String(data: data, encoding: .utf8), str.length > 0 {
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
        outpipe.fileHandleForReading.closeFile()
        errpipe.fileHandleForReading.closeFile()
    }
    return process
}
