//
//  ProgressViewController+Download.swift
//  NicoDownloader
//
//  Created by Jeong on 2017. 1. 21..
//  Copyright © 2017년 Jeong. All rights reserved.
//

import Foundation
import Cocoa

import Alamofire
import Kanna
import PromiseKit

extension ProgressViewController {
    
    func initSessionManager() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.httpCookieStorage = cookies
        sessionManager = Alamofire.SessionManager(configuration: configuration)
    }
    
    func login() -> Promise<Void> {
        return Promise { fulfill, reject in
            self.updateStatusMessage(message: "Logging in...")
            let url = "https://secure.nicovideo.jp/secure/login?site=niconico&mail=\(account.email)&password=\(account.password)"
            sessionManager.request(url, method: .post).responseString { response in
                switch response.result {
                case .success(let htmlString):
                    if let doc = HTML(html: htmlString, encoding: .utf8), doc.css("div.notice.error").count == 0 {
                        fulfill()
                    } else {
                        reject(NicoError.LoginError)
                    }
                case .failure(let error):
                    reject(error)
                }
            }
        }
    }
    
    func createItems(fromMylistId: String) -> Promise<Array<Item>> {
        return Promise { fulfill, reject in
            self.updateStatusMessage(message: "Fetching items...")
            let url = "http://www.nicovideo.jp/mylist/\(fromMylistId)?rss=2.0"
            sessionManager.request(url, method: .get).responseString { response in
                switch response.result {
                case .success(let xmlString):
                    guard let doc = Kanna.XML(xml: xmlString, encoding: .utf8) else {
                        reject(NicoError.FetchVideoIdsError("Malformed xml"))
                        return
                    }
                    let itemXmls = doc.xpath("//item")
                    guard itemXmls.count > 0 else {
                        reject(NicoError.FetchVideoIdsError("Invalid mylist ID"))
                        return
                    }
                    
                    var items: [Item] = []
                    for itemXml in itemXmls {
                        guard let link = itemXml.at_xpath("link")?.text,
                            let videoId = link.components(separatedBy: "/").last,
                            let title = itemXml.at_xpath("title")?.text,
                            let pubdateString = itemXml.at_xpath("pubDate")?.text,
                            let pubdate = DateFormatter.from(pubdateString: pubdateString) else {
                                continue
                        }
                        
                        items.append(Item(videoId: videoId, name: title, pubdate: pubdate))
                    }
                    items.sort(by: { (lhs, rhs) -> Bool in
                        lhs.pubdate.compare(rhs.pubdate) == .orderedAscending
                    })
                    fulfill(items)
                case .failure(let error):
                    reject(error)
                }
            }
            
        }
    }
    
    func download() {
        self.updateStatusMessage(message: "Downloading items...")
        downloadWorkItem = DispatchWorkItem {
            let semaphore = DispatchSemaphore(value: 1)
            for (idx, item) in self.items.enumerated() {
                Thread.sleep(forTimeInterval: 3)
                self.items[idx].status = .fetching
                self.getVideoUrlWith(item: item) { url in
                    self.prefetchVideoPage(videoId: item.videoId) {
                        self.items[idx].status = .downloading
                        self.downloadVideo(item: item, url: url, progressCallback: {
                            self.items[idx].progress = $0
                            DispatchQueue.main.async(execute: {
                                self.downloadProgressTableView.reloadData()
                            })
                        }) { succeed in
                            self.items[idx].status = .done
                            semaphore.signal()
                            DispatchQueue.main.async {
                                self.downloadProgressTableView.reloadData()
                                let allDone = self.items.reduce(true) { $0.0 && ($0.1.status == .done) }
                                if allDone {
                                    self.updateStatusMessage(message: "DONE")
                                }
                                
                            }
                        }
                    }
                }
                let _ = semaphore.wait(timeout: .distantFuture)
                if self.cancelled {
                    break
                }
            }
        }
        DispatchQueue.global(qos: .default).async(execute: downloadWorkItem!)
    }
    
    func getVideoUrlWith(item: Item, callback: @escaping StringCallback) {
        let videoApiUrl = "http://flapi.nicovideo.jp/api/getflv/\(item.videoId)?as3=1"
        sessionManager.request(videoApiUrl).responseString { response in
            guard let htmlString = response.result.value else {
                return
            }
            let url = htmlString.components(separatedBy: "&")
                .map { $0.components(separatedBy: "=") }
                .filter { $0[0] == "url" }
                .map { $0[1] }[0]
            guard let decodedUrl = url.removingPercentEncoding else {
                return
            }
            callback(decodedUrl)
        }
    }
    
    func prefetchVideoPage(videoId: String, callback: @escaping Callback) {
        let videoUrl = "http://www.nicovideo.jp/watch/\(videoId)?watch_harmful=1"
        sessionManager.request(videoUrl).responseString { response in
            guard response.result.value != nil else {
                print("prefetchVideoPage failed: \(videoId)")
                return
            }
            callback()
        }
    }
    
    func downloadVideo(item: Item, url: String, progressCallback: @escaping DoubleCallback,
                       finishCallback: @escaping BoolCallback) {
        guard !cancelled else {
            finishCallback(false)
            return
        }
        let destination: DownloadRequest.DownloadFileDestination = { temporaryURL, response in
            let downloadsURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]
            var fileURL = downloadsURL.appendingPathComponent(item.name)
            if let fileExtension = (response.suggestedFilename as NSString?)?.pathExtension {
                fileURL = fileURL.appendingPathExtension(fileExtension)
            }
            
            return (fileURL, [.removePreviousFile, .createIntermediateDirectories])
        }
        let request = sessionManager.download(url, to: destination)
            .downloadProgress { progress in
                progressCallback(progress.fractionCompleted)
            }.responseData { response in
                finishCallback(response.result.value != nil)
        }
        downloadRequests.append(request)
    }
}
