//
//  ProgressViewController.swift
//  NicoDownloader
//
//  Created by Jeong on 2017. 1. 19..
//  Copyright © 2017년 Jeong. All rights reserved.
//

import Cocoa

import Alamofire
import Kanna

typealias Callback = () -> Void
typealias BoolCallback = (Bool) -> Void
typealias DoubleCallback = (Double) -> Void
typealias StringCallback = (String) -> Void

class ProgressViewController: NSViewController {
    @IBOutlet weak var downloadProgressTableView: NSTableView!
    
    var account: Account!
    var items: [(Item)] = []
    var sessionManager: Alamofire.SessionManager!
    
    let cookies = HTTPCookieStorage.shared

    override func viewDidLoad() {
        super.viewDidLoad()
        
        initTableView()
        initSessionManager()
        
        login()
    }
    
    private func initTableView() {
        downloadProgressTableView.delegate = self
        downloadProgressTableView.dataSource = self
    }
}

extension ProgressViewController {
    
    func initSessionManager() {
        let configuration = URLSessionConfiguration.default
//        configuration.httpMaximumConnectionsPerHost = 1
        configuration.timeoutIntervalForRequest = 30
        configuration.httpCookieStorage = cookies
        sessionManager = Alamofire.SessionManager(configuration: configuration)
    }
    
    func login() {
        let url = "https://secure.nicovideo.jp/secure/login?site=niconico&mail=\(account.email)&password=\(account.password)"
        sessionManager.request(url, method: .post).responseString { response in
            guard let htmlString = response.result.value else {
                return
            }
            if let doc = HTML(html: htmlString, encoding: .utf8), doc.css("div.notice.error").count == 0 {
                print("Login succeed")
                self.videoIdsFrom(mylistId: "48890167")
            } else {
                print("Login failed")
            }
        }
    }
    
    func videoIdsFrom(mylistId: String) {
        let url = "http://www.nicovideo.jp/mylist/\(mylistId)?rss=2.0"
        sessionManager.request(url, method: .get).responseString { response in
            guard let xmlString = response.result.value, let doc = Kanna.XML(xml: xmlString, encoding: .utf8) else {
                return
            }
            let itemXmls = doc.xpath("//item")
            for itemXml in itemXmls {
                guard let link = itemXml.at_xpath("link")?.text,
                    let videoId = link.components(separatedBy: "/").last,
                    let title = itemXml.at_xpath("title")?.text,
                    let pubdateString = itemXml.at_xpath("pubDate")?.text,
                    let pubdate = DateFormatter.from(pubdateString: pubdateString) else {
                        continue
                }
                
                self.items.append(Item(videoId: videoId, name: title, pubdate: pubdate))
            }
            self.items.sort(by: { (lhs, rhs) -> Bool in
                lhs.pubdate.compare(rhs.pubdate) == .orderedAscending
            })
            self.items = Array(self.items[0..<3])
            print("item parsed: \(self.items.count)")
            self.download()
        }
    }
    
    func download() {
        DispatchQueue.global(qos: .default).async {
            let semaphore = DispatchSemaphore(value: 1)
            for (idx, item) in self.items.enumerated() {
                print("sleeping...\(idx)")
                Thread.sleep(forTimeInterval: 3)
                print("awake\(idx)")
                self.getVideoUrlWith(item: item) { url in
                    print("\(idx): \(url)")
                    self.prefetchVideoPage(videoId: item.videoId) {
                        print("\(idx): prefetched")
                        
                        print("main: \(idx)")
                        self.downloadVideo(item: item, url: url, progressCallback: {
                            self.items[idx].progress = $0
                            DispatchQueue.main.async(execute: {
                                self.downloadProgressTableView.reloadData()
                            })
                        }) { succeed in
                            print(succeed)
                            semaphore.signal()
                        }
                    }
                }
                semaphore.wait(timeout: .distantFuture)
            }
        }
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
        let destination: DownloadRequest.DownloadFileDestination = { temporaryURL, response in
            let downloadsURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]
            var fileURL = downloadsURL.appendingPathComponent(item.name)
            if let fileExtension = (response.suggestedFilename as NSString?)?.pathExtension {
                fileURL = fileURL.appendingPathExtension(fileExtension)
            }
            
            return (fileURL, [.removePreviousFile, .createIntermediateDirectories])
        }
        sessionManager.download(url, to: destination)
            .downloadProgress { progress in
                progressCallback(progress.fractionCompleted)
            }.responseData { response in
                finishCallback(response.result.value != nil)
        }
    }
}

extension ProgressViewController: NSTableViewDataSource {
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return items.count
    }
}

extension ProgressViewController: NSTableViewDelegate {
    
    fileprivate enum CellIdentifiers {
        static let NumberCell = "NumberCellID"
        static let TitleCell = "TitleCellID"
        static let ProgressCell = "ProgressCellID"
    }
    
    func tableView(_ tableView: NSTableView, viewFor optionalTableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let tableColumn = optionalTableColumn else {
            return nil
        }
        let item = items[row]
        
        switch tableColumn {
        case tableView.tableColumns[0]:
            if let cell = tableView.make(withIdentifier: CellIdentifiers.NumberCell, owner: nil) as? NSTableCellView {
                cell.textField?.stringValue = String(row)
                return cell
            }
        case tableView.tableColumns[1]:
            if let cell = tableView.make(withIdentifier: CellIdentifiers.TitleCell, owner: nil) as? NSTableCellView {
                cell.textField?.stringValue = item.name ?? ""
                return cell
            }
        default:
            if let cell = tableView.make(withIdentifier: CellIdentifiers.ProgressCell, owner: nil) as? ProgressTableCellView {
                cell.progressIndicator.doubleValue = Double(item.progress)
                return cell
            }
        }
        return nil
    }
    
//    func tableViewSelectionDidChange(_ notification: Notification) {
//        let row = downloadProgressTableView.selectedRow
//        guard row >= 0 else {
//                return
//        }
//        items[row].progress += 4
//        downloadProgressTableView.reloadData()
//    }
}
