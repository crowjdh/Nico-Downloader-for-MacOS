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

struct NicoCommentEncoding: ParameterEncoding {
    private let threadId: String
    
    init(threadId: String) {
        self.threadId = threadId
    }
    
    func encode(_ urlRequest: URLRequestConvertible, with parameters: Parameters?) throws -> URLRequest {
        guard var urlRequest = urlRequest.urlRequest else {
            throw NicoError.UnknownError("URLRequestConvertible has no URLRequest")
        }
        
        let xml = "<thread res_from='-1000' version='20061206' thread='\(threadId)' />"
        
        if urlRequest.value(forHTTPHeaderField: "Content-Type") == nil {
            urlRequest.setValue("text/xml", forHTTPHeaderField: "Content-Type")
        }
        
        urlRequest.httpBody = xml.data(using: .utf8)
        
        return urlRequest
    }
}

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
                    self.getVideoApiInfoWith(item: item)
                }.then { apiInfo -> Promise<String> in
                    self.items[idx].apiInfo = apiInfo
                    return self.prefetchVideoPage(videoId: item.videoId)
                }.then { title -> Promise<Void> in
                    self.items[idx].name = self.items[idx].name ?? title
                // TOOD: Add below to download comment
//                    return self.downloadCommentXml(item: self.items[idx])
//                }.then { _ -> Promise<Void> in
                    self.items[idx].status = .downloading
                    return self.downloadVideo(item: self.items[idx], url: self.items[idx].apiInfo["url"]!, progressCallback: {
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
    
    func getVideoApiInfoWith(item: Item) -> Promise<[String: String]> {
        return Promise { fulfill, reject in
            let videoApiUrl = "http://flapi.nicovideo.jp/api/getflv/\(item.videoId)?as3=1"
            sessionManager.request(videoApiUrl).responseString { response in
                guard let htmlString = response.result.value else {
                    reject(NicoError.VideoAPIError)
                    return
                }
                var apiInfo = [String: String]()
                let apiInfoArray = htmlString.components(separatedBy: "&")
                for component in apiInfoArray {
                    let keyValueTuple = component.components(separatedBy: "=")
                    let key = keyValueTuple[0]
                    var value = keyValueTuple[1]
                    if key.contains("url") || key.contains("ms") {
                        guard let decodedUrl = value.removingPercentEncoding else {
                            reject(NicoError.VideoAPIError)
                            return
                        }
                        value = decodedUrl
                    }
                    apiInfo[key] = value
                }
                fulfill(apiInfo)
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
    
    func downloadCommentXml(item: Item) -> Promise<Void> {
        return Promise { fulfill, reject in
            sessionManager.request(item.apiInfo["ms"]!, method: .post, encoding: NicoCommentEncoding(threadId: item.apiInfo["thread_id"]!)).responseString(encoding: String.Encoding.utf8) { response in
                switch response.result {
                case .success(let xmlString):
                    guard !self.cancelled else {
                        reject(NicoError.Cancelled)
                        return
                    }
                    let comments = Comment.fromXml(xmlString)
                    // TODO: convert(save also?) comments into "drawtext" filters
                    let downloadsURL = self.options.saveDirectory
                    let fileURL = downloadsURL.appendingPathComponent(item.name).appendingPathExtension("comment")
                    try! xmlString.write(to: fileURL, atomically: false, encoding: String.Encoding.utf8)
                    fulfill()
                case .failure(let error):
                    reject(error)
                }
            }
        }
    }
}
