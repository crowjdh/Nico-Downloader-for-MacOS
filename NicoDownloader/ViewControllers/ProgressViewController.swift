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
import PromiseKit

typealias Callback = () -> Void
typealias BoolCallback = (Bool) -> Void
typealias DoubleCallback = (Double) -> Void
typealias StringCallback = (String) -> Void

enum NicoError: Error {
    case LoginError
    case FetchVideoIdsError(String)
}

class ProgressViewController: NSViewController {
    @IBOutlet weak var downloadProgressTableView: NSTableView!
    
    var account: Account!
    var options: Options!
    var items: [Item] = []
    var sessionManager: Alamofire.SessionManager!
    var cancelled = false
    var downloadRequests: [DownloadRequest] = []
    var downloadWorkItem: DispatchWorkItem?
    var semaphore: DispatchSemaphore?
    
    let cookies = HTTPCookieStorage.shared
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        initTableView()
        initSessionManager()
        
        firstly {
            login()
        }.then {
            self.createItems(fromMylistId: self.options.mylistID)
        }.then{ items -> Void in
            self.items = items
            self.downloadProgressTableView.reloadData()
            self.download()
        }.catch { error in
            print(error)
        }
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        
        view.window?.delegate = self
    }
    
    private func initTableView() {
        downloadProgressTableView.delegate = self
        downloadProgressTableView.dataSource = self
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
                    items = Array(items[0..<3])
                    fulfill(items)
                case .failure(let error):
                    reject(error)
                }
            }
            
        }
    }
    
    func download() {
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
        static let StatusCell = "StatusCellID"
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
                cell.textField?.stringValue = item.name
                return cell
            }
        case tableView.tableColumns[2]:
            if let cell = tableView.make(withIdentifier: CellIdentifiers.ProgressCell, owner: nil) as? ProgressTableCellView {
                cell.progressIndicator.doubleValue = Double(item.progress)
                return cell
            }
        default:
            if let cell = tableView.make(withIdentifier: CellIdentifiers.StatusCell, owner: nil) as? NSTableCellView {
                cell.textField?.stringValue = item.status.description
                return cell
            }
        }
        return nil
    }
}

extension ProgressViewController: NSWindowDelegate {
    
    func windowShouldClose(_ sender: Any) -> Bool {
        if !cancelled {
            let alert = NSAlert()
            alert.messageText = "Are you sure you want to stop download?"
            alert.addButton(withTitle: "OK")
            alert.addButton(withTitle: "Cancel")
            alert.beginSheetModal(for: view.window!) { response in
                if response == NSAlertFirstButtonReturn {
                    self.cancelled = true
                }
            }
        }
        
        return cancelled
    }
    
    func windowDidEndSheet(_ notification: Notification) {
        if cancelled {
            if let downloadWorkItem = self.downloadWorkItem {
                downloadWorkItem.cancel()
            }
            for downloadRequest in self.downloadRequests {
                downloadRequest.cancel()
            }
            self.view.window!.performClose(self)
        }
    }
}
