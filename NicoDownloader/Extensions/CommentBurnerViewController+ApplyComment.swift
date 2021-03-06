//
//  CommentBurnerViewController+ApplyComment.swift
//  NicoDownloader
//
//  Created by Jeong on 2017. 4. 9..
//  Copyright © 2017년 Jeong. All rights reserved.
//

import Foundation
import PromiseKit

extension CommentBurnerViewController: CommentBurnerable {
    var allDone: Bool {
        get {
            return self.items.reduce(true) { $0 && ($1.status == .done || $1.status == .error) }
        }
    }
    
    func applyComment(item: FilterItem, progressCallback: @escaping DoubleCallback) -> Promise<Void> {
        return Promise { seal in
            guard let videoFileURL = item.videoFileURL,
                let filterFileURL = item.filterFileURL else {
                    seal.reject(NicoError.UnknownError("Video and/or filter file does not exists"))
                    return
            }
            let res = applyComment(videoFileURL: videoFileURL, filterFileURL: filterFileURL,
                                   progressCallback: progressCallback, callback: { output, error, status in
                                    if status == 0 {
                                        seal.fulfill_()
                                    } else {
                                        seal.reject(NicoError.UnknownError(error.joined(separator: "\n")))
                                    }
            })
            if let res = res {
                self.filterProcesses.append(res)
            } else {
                seal.reject(NicoError.UnknownError("Error occurred while applying comment"))
            }
        }
    }
    
    func reloadTableViewData() {
        DispatchQueue.main.async(execute: {
            self.videosTableView.reloadData()
            self.filterTableView.reloadData()
        })
    }
    
    func checkIfAllDone() {
        if self.allDone {
            DispatchQueue.main.async {
                NSApplication.shared.requestUserAttention(.informationalRequest)
                NSUserNotificationCenter.notifyTaskDone() { notification in
                    notification.title = "All tasks done"
                    notification.subtitle = "Applied comments to all videos"
                }
            }
        }
    }
    
    func startTask() {
        task = DispatchWorkItem {
            // TODO: Consider retrieve below as option
            let concurrentDownloadCount = 2
            let semaphore = DispatchSemaphore(value: concurrentDownloadCount - 1)
            for (idx, item) in self.items.enumerated() {
                guard let _ = item.videoFileURL,
                    let commentFileURL = item.commentFileURL,
                    let videoFilePath = item.videoFilePath else {
                    continue
                }
                
                self.items[idx].videoDuration = getVideoDuration(inputFilePath: videoFilePath)
                self.items[idx].status = .filtering
                
                let filterFileURL = try! Comment.saveFilterFile(
                    fromCommentFile: commentFileURL, item: item)
                self.items[idx].filterFileURL = filterFileURL
                self.applyComment(item: self.items[idx], progressCallback: { progress in
                    self.items[idx].filterProgress = progress / self.items[idx].videoDuration
                    self.reloadTableViewData()
                }).done { _ -> Void in
                    self.items[idx].status = .done
                    self.togglePreventSleep()
                    semaphore.signal()
                    self.reloadTableViewData()
                    self.checkIfAllDone()
                }.catch { error in
                    switch error {
                    case NicoError.UnknownError(let msg):
                        print(msg)
                    default:
                        print(error.localizedDescription)
                    }
                    self.items[idx].status = .error
                    semaphore.signal()
                    self.togglePreventSleep()
                    self.reloadTableViewData()
                    self.checkIfAllDone()
                }
                
                let _ = semaphore.wait(timeout: .distantFuture)
                if self.cancelled {
                    break
                }
            }
        }
        DispatchQueue.global(qos: .default).async(execute: task!)
    }
}

extension CommentBurnerViewController {
    
    func togglePreventSleep() {
        !allDone ? powerManager.preventSleep() : powerManager.releaseSleepAssertion()
    }
}
