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

typealias DoubleCallback = (Double) -> Void

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
                    guard !self.cancelled else {
                        reject(NicoError.Cancelled)
                        return
                    }
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
    
    func createItems(fromMylist mylist: Mylist) -> Promise<Array<Item>> {
        return Promise { fulfill, reject in
            self.updateStatusMessage(message: "Fetching items...")
            let url = "http://www.nicovideo.jp/mylist/\(mylist.id)?rss=2.0"
            sessionManager.request(url, method: .get).responseString { response in
                switch response.result {
                case .success(let xmlString):
                    guard !self.cancelled else {
                        reject(NicoError.Cancelled)
                        return
                    }
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
                        // Force unwrap since we're setting pubdate from above
                        lhs.pubdate!.compare(rhs.pubdate!) == .orderedAscending
                    })
                    
                    if var from = mylist.range?.lowerBound, var to = mylist.range?.upperBound {
                        let largestIndex = items.count - 1
                        from = min(from, largestIndex)
                        to = min(to, largestIndex)
                        items = Array(items[from...to])
                    }
                    
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
            let semaphore = DispatchSemaphore(value: self.options.concurrentDownloadCount - 1)
            for (idx, item) in self.items.enumerated() {
                Thread.sleep(forTimeInterval: 3)
                self.items[idx].status = .fetching
                
                firstly {
                    self.getVideoUrlWith(item: item)
                }.then { url -> Promise<String> in
                    self.items[idx].videoUrl = url
                    return self.prefetchVideoPage(videoId: item.videoId)
                }.then { title -> Promise<Void> in
                    self.items[idx].name = self.items[idx].name ?? title
                    self.items[idx].status = .downloading
                    return self.downloadVideo(item: self.items[idx], url: self.items[idx].videoUrl!, progressCallback: {
                        self.items[idx].progress = $0
                        DispatchQueue.main.async(execute: {
                            self.downloadProgressTableView.reloadData()
                        })
                    })
                }.then { _ -> Void in
                    self.items[idx].status = .done
                    self.togglePreventSleep()
                    semaphore.signal()
                    DispatchQueue.main.async {
                        self.downloadProgressTableView.reloadData()
                        
                        if self.allDone {
                            self.updateStatusMessage(message: "DONE")
                        }
                    }
                }.catch { error in
                    self.items[idx].status = .error
                    semaphore.signal()
                    self.togglePreventSleep()
                    DispatchQueue.main.async {
                        self.downloadProgressTableView.reloadData()
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
    
    func getVideoUrlWith(item: Item) -> Promise<String> {
        return Promise { fulfill, reject in
            let videoApiUrl = "http://flapi.nicovideo.jp/api/getflv/\(item.videoId)?as3=1"
            sessionManager.request(videoApiUrl).responseString { response in
                guard let htmlString = response.result.value else {
                    reject(NicoError.VideoAPIError)
                    return
                }
                let url = htmlString.components(separatedBy: "&")
                    .map { $0.components(separatedBy: "=") }
                    .filter { $0[0] == "url" }
                    .map { $0[1] }[0]
                guard let decodedUrl = url.removingPercentEncoding else {
                    reject(NicoError.VideoAPIError)
                    return
                }
                fulfill(decodedUrl)
            }
        }
    }
    
    func prefetchVideoPage(videoId: String) -> Promise<String> {
        return Promise { fulfill, reject in
            let videoUrl = "http://www.nicovideo.jp/watch/\(videoId)?watch_harmful=1"
            sessionManager.request(videoUrl).responseString { response in
                guard let htmlString = response.result.value,
                    let doc = HTML(html: htmlString, encoding: .utf8),
                    let title = doc.title?.replacingOccurrences(of: "/", with: "／") else {
                    reject(NicoError.FetchVideoPageError)
                    return
                }
                fulfill(title)
            }
        }
    }
    
    func downloadVideo(item: Item, url: String, progressCallback: @escaping DoubleCallback) -> Promise<Void> {
        return Promise { fulfill, reject in
            guard !cancelled else {
                reject(NicoError.Cancelled)
                return
            }
            let destination: DownloadRequest.DownloadFileDestination = { temporaryURL, response in
                let downloadsURL = self.options.saveDirectory
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
                    guard response.result.value != nil else {
                        reject(NicoError.UnknownError("Download failed"))
                        return
                    }
                    fulfill()
            }
            downloadRequests.append(request)
        }
    }
}
