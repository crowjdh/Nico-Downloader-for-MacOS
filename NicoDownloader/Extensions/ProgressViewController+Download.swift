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
typealias ThreadKeyAPIResult = (String, String)
typealias StringKeyDictionary = Dictionary<String, Any>
typealias VideoPageInfo = (String, String?)

struct NicoCommentEncoding: ParameterEncoding {
    private let threadID: String
    private let userID: String
    private let threadAPIResult: ThreadKeyAPIResult?
    
    init(threadID: String, userID: String, threadAPIResult: ThreadKeyAPIResult?) {
        self.threadID = threadID
        self.userID = userID
        self.threadAPIResult = threadAPIResult
    }
    
    func encode(_ urlRequest: URLRequestConvertible, with parameters: Parameters?) throws -> URLRequest {
        guard var urlRequest = urlRequest.urlRequest else {
            throw NicoError.UnknownError("URLRequestConvertible has no URLRequest")
        }
        var threadKeyAPIInfo = ""
        if let threadAPIResult = threadAPIResult {
            threadKeyAPIInfo = "threadkey='\(threadAPIResult.0)' force_184='\(threadAPIResult.1)'"
        }
        
        let xml = "<thread res_from='-1000' version='20061206' scores='1' user_id='\(userID)' thread='\(threadID)' \(threadKeyAPIInfo) />"
        
        if urlRequest.value(forHTTPHeaderField: "Content-Type") == nil {
            urlRequest.setValue("text/xml", forHTTPHeaderField: "Content-Type")
        }
        
        urlRequest.httpBody = xml.data(using: .utf8)
        
        return urlRequest
    }
}

extension ProgressViewController: CommentBurnerable {
    
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
                    if let doc = try? HTML(html: htmlString, encoding: .utf8),
                        doc.css("div.notice.error").count == 0 {
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
    
    func createItems(fromMylist mylist: Mylist) -> Promise<Array<NicoItem>> {
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
                    guard let doc = try? Kanna.XML(xml: xmlString, encoding: .utf8) else {
                        reject(NicoError.FetchVideoIdsError("Malformed xml"))
                        return
                    }
                    let itemXmls = doc.xpath("//item")
                    guard itemXmls.count > 0 else {
                        reject(NicoError.FetchVideoIdsError("Invalid mylist ID"))
                        return
                    }
                    
                    var items: [NicoItem] = []
                    for itemXml in itemXmls {
                        guard let link = itemXml.at_xpath("link")?.text,
                            let videoId = link.components(separatedBy: "/").last,
                            let title = itemXml.at_xpath("title")?.text,
                            let pubdateString = itemXml.at_xpath("pubDate")?.text,
                            let pubdate = DateFormatter.from(pubdateString: pubdateString) else {
                                continue
                        }
                        
                        items.append(NicoItem(videoId: videoId, name: title, pubdate: pubdate))
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
    
    func reloadTableViewData() {
        DispatchQueue.main.async(execute: {
            self.downloadProgressTableView.reloadData()
        })
    }
    
    func checkIfAllDone() {
        if self.allDone {
            DispatchQueue.main.async {
                NSApplication.shared().requestUserAttention(.informationalRequest)
                NSUserNotificationCenter.notifyTaskDone() { notification in
                    notification.title = "All tasks done"
                    notification.subtitle = "Downloaded all videos"
                }
                self.updateStatusMessage(message: "DONE")
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
                self.reloadTableViewData()
                
                firstly {
                    self.getVideoApiInfoWith(item: item)
                }.then { apiInfo -> Promise<VideoPageInfo> in
                    self.items[idx].apiInfo = apiInfo
                    // TODO: Change to thumbnail api
                    // TODO: Also, add referer(http://www.nicovideo.jp/watch/[動画番号]) to download request
                    return self.prefetchVideoPage(videoId: item.videoId)
                }.then { videoPageInfo -> Promise<URL> in
                    self.items[idx].name = self.items[idx].name ?? videoPageInfo.0
                    self.items[idx].apiInfo["url_alt"] = videoPageInfo.1
                    self.items[idx].status = .downloading
                    let item = self.items[idx]

                    // TODO: Remove below when test is over
//                    return Promise<URL>(value: URL(fileURLWithPath: "/Users/jeong/Downloads/nico/【実況】いい大人達がプリンセスメーカー２を本気で遊んでみた。part1 - Niconico Video.mp4"))
                    return self.downloadVideo(item: item, progressCallback: {
                        self.items[idx].progress = $0
                        self.reloadTableViewData()
                    })
                }.then { destinationURL -> Promise<URL?> in
                    self.items[idx].videoFileURL = destinationURL
                    return self.downloadCommentXml(item: self.items[idx])
                }.then { filterURL -> Promise<Void> in
                    guard let filterURL = filterURL, self.options.applyComment else {
                        return Promise<Void>.init(value: ())
                    }
                    self.items[idx].filterFileURL = filterURL
                    self.items[idx].status = .filtering
                    self.items[idx].duration = getVideoDuration(inputFilePath: self.items[idx].videoFilePath)
                    self.reloadTableViewData()
                    // TODO: Consider showing progress
                    return self.applyComment(item: self.items[idx]) {
                        self.items[idx].filterProgress = $0 / self.items[idx].duration
                        self.reloadTableViewData()
                    }
                }.then { _ -> Void in
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
        DispatchQueue.global(qos: .default).async(execute: downloadWorkItem!)
    }
    
    func getVideoApiInfoWith(item: NicoItem) -> Promise<[String: String]> {
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
    
    func prefetchVideoPage(videoId: String) -> Promise<VideoPageInfo> {
        return Promise { fulfill, reject in
            let videoUrl = "http://www.nicovideo.jp/watch/\(videoId)?watch_harmful=1"
            
            let headers: HTTPHeaders = [
                "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_13_0) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/61.0.3163.100 Safari/537.36"
            ]
            sessionManager.request(videoUrl, headers: headers).responseString { [weak self] response in
                guard let htmlString = response.result.value,
                    let doc = try? HTML(html: htmlString, encoding: .utf8),
                    let title = doc.title?.replacingOccurrences(of: "/", with: "／") else {
                    reject(NicoError.FetchVideoPageError)
                    return
                }
                let videoURL = self?.getVideoURLFromVideoPage(document: doc)
                
                fulfill((title, videoURL))
            }
        }
    }
    
    private func getVideoURLFromVideoPage(document: HTMLDocument) -> String? {
        let watchData = document.at_css("div#js-initial-watch-data")
        let apiData = watchData?["data-api-data"]
        guard let videoDict = apiData?.convertToDictionary()?["video"] as? StringKeyDictionary,
            let smileInfo = videoDict["smileInfo"] as? StringKeyDictionary,
            let url = smileInfo["url"] as? String else {
                return nil
        }
        return url
    }
    
    func downloadVideo(item: NicoItem, progressCallback: @escaping DoubleCallback) -> Promise<URL> {
        return Promise { fulfill, reject in
            guard !cancelled else {
                reject(NicoError.Cancelled)
                return
            }
            let destination: DownloadRequest.DownloadFileDestination = { temporaryURL, response in
                let downloadsURL = self.options.saveDirectory
                var fileURL = downloadsURL.appendingPathComponent(item.name, isDirectory: false)
                if let fileExtension = (response.suggestedFilename as NSString?)?.pathExtension {
                    fileURL = fileURL.appendingPathExtension(fileExtension)
                }
                
                return (fileURL, [.removePreviousFile, .createIntermediateDirectories])
            }
            
            downloadVideoFromURL(url: item.apiInfo["url"]!, to: destination,
                progressCallback: progressCallback, fulfill: fulfill,
                reject: { [weak self] error in
                    guard let me = self else {
                        return
                    }
                    me.downloadVideoFromURL(url: item.apiInfo["url_alt"]!, to: destination,
                         progressCallback: progressCallback, fulfill: fulfill,
                         reject: { error in
                            reject(error)
                    })
            })
        }
    }
    
    private func downloadVideoFromURL(url: String, to destination: @escaping DownloadRequest.DownloadFileDestination,
                                      progressCallback: @escaping DoubleCallback,
                                      fulfill: @escaping (URL) -> Void, reject: @escaping (Error) -> Void) {
        let request = sessionManager.download(url, to: destination).validate()
            .downloadProgress { progress in
                progressCallback(progress.fractionCompleted)
            }.responseData { response in
                guard let fileURL = response.destinationURL, response.result.value != nil else {
                    reject(NicoError.UnknownError("Download failed"))
                    return
                }
                fulfill(fileURL)
        }
        downloadRequests.append(request)
    }
    
    func downloadCommentXml(item: NicoItem) -> Promise<URL?> {
        return Promise { fulfill, reject in
            let hasNumaricVideoId = Int(item.videoId) != nil
            if hasNumaricVideoId {
                getThreadKey(videoId: item.videoId).then { threadKeyAPIResult -> Promise<URL?> in
                    return self.downloadCommentXml(item: item, threadAPIResult: threadKeyAPIResult)
                }.then { url -> Void in
                    fulfill(url)
                }.catch { error in
                    reject(error)
                }
            } else {
                downloadCommentXml(item: item, threadAPIResult: nil).then { url in
                    fulfill(url)
                }.catch { error in
                    reject(error)
                }
            }
            
        }
    }
    
    func getThreadKey(videoId: String) -> Promise<ThreadKeyAPIResult> {
        return Promise { fulfill, reject in
            sessionManager.request(
                "http://flapi.nicovideo.jp/api/getthreadkey?thread=\(videoId)",
                method: .get, headers: ["Content-Type":"text/xml"])
                .responseString(encoding: String.Encoding.utf8) { response in
                    guard let htmlString = response.result.value else {
                        reject(NicoError.UnknownError("Thread key not found"))
                        return
                    }
                    let apiInfoArray = htmlString.components(separatedBy: "&")
                    var threadKey: String? = nil
                    var force184: String? = nil
                    for component in apiInfoArray {
                        let keyValueTuple = component.components(separatedBy: "=")
                        let key = keyValueTuple[0]
                        let value = keyValueTuple[1]
                        switch key {
                        case "threadkey": threadKey = value
                        case "force_184": force184 = value
                        default:
                            break
                        }
                    }
                    if let threadKey = threadKey, let force184 = force184 {
                        fulfill((threadKey, force184))
                    } else {
                        reject(NicoError.UnknownError("Insufficient thread key information"))
                    }
            }
        }
    }
    
    func downloadCommentXml(item: NicoItem, threadAPIResult: ThreadKeyAPIResult?) -> Promise<URL?> {
        return Promise { fulfill, reject in
            guard let host = item.apiInfo["ms"], let threadID = item.apiInfo["thread_id"], let userID = item.apiInfo["user_id"] else {
                reject(NicoError.UnknownError("Insufficient api information"))
                return
            }
            sessionManager.request(host, method: .post, encoding: NicoCommentEncoding(threadID: threadID, userID: userID, threadAPIResult: threadAPIResult)).responseString(encoding: String.Encoding.utf8) { response in
                switch response.result {
                case .success(let xmlString):
                    guard !self.cancelled else {
                        reject(NicoError.Cancelled)
                        return
                    }
                    
                    var filterURL: URL? = nil
                    do {
                        try Comment.saveOriginalComment(
                            fromXmlString: xmlString, item: item)
                        filterURL = try Comment.saveFilterFile(
                            fromXmlString: xmlString, item: item)
                    } catch {
                        print("Error occurred while saving comments")
                    }
                    fulfill(filterURL)
                case .failure(let error):
                    reject(error)
                }
            }
        }
    }
    
    func applyComment(item: NicoItem, progressCallback: @escaping DoubleCallback) -> Promise<Void> {
        return Promise { fulfill, reject in
            guard let filterURL = item.filterFileURL else {
                fulfill()
                return
            }
            let res = applyComment(videoFileURL: item.videoFileURL,
                         filterFileURL: filterURL,
                         progressCallback: progressCallback, callback: { output, error, status in
                            if status == 0 {
                                fulfill()
                            } else {
                                reject(NicoError.UnknownError(error.joined(separator: "\n")))
                            }
            })
            if let res = res {
                self.filterProcesses.append(res.0)
                self.filterWorkItems.append(res.1)
            }
        }
    }
}
