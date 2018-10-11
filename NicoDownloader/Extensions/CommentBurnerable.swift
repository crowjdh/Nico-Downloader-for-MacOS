//
//  CommentBurnerable.swift
//  NicoDownloader
//
//  Created by Jeong on 2017. 4. 9..
//  Copyright © 2017년 Jeong. All rights reserved.
//

import Foundation

protocol CommentBurnerable {}

extension CommentBurnerable {
    func applyComment(videoFileURL: URL, filterFileURL: URL,
                      progressCallback: @escaping DoubleCallback,
                      callback: @escaping (ProcessResult) -> Void) -> Process? {
        return filterVideo(
            inputFilePath: videoFileURL.absoluteString.removingPercentEncoding!,
            outputFilePath: videoFileURL.commentedVideoURL.absoluteString.removingPercentEncoding!,
            filterPath: filterFileURL.absoluteString.removingPercentEncoding!,
            progressCallback: { output in
                if let encodedTime = encodedTime(fromOutput: output) {
                    progressCallback(encodedTime)
                }
        }) { processResult in
            callback(processResult)
        }
    }
}
