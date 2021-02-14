//
//  ProgressViewController+NewApi.swift
//  NicoDownloader
//
//  Created by Donghyun Jung on 2021/02/05.
//  Copyright © 2021 Jeong. All rights reserved.
//

import Foundation
import Alamofire
import PromiseKit
import SwiftSoup
import SwiftyJSON

typealias StringResponse = (string: String, response: PMKAlamofireDataResponse)
typealias DataResponse = (data: Data, response: PMKAlamofireDataResponse)
typealias StringRequest = Promise<StringResponse>
typealias DataRequest = Promise<DataResponse>
typealias Headers = [String:String]

let maxCommentCnt = Int(72e3);
let defaultCommentCntPerLeaf = 100;

class Retrier: RequestRetrier {
    let retryLimit = 3
    func should(_ manager: SessionManager, retry request: Request, with error: Error, completion: @escaping RequestRetryCompletion) {
        if request.retryCount < retryLimit {
            let timeDelay = pow(Double(2), Double(request.retryCount)) * 2
            completion(true, timeDelay)
        } else {
            completion(false, 0)
        }
    }
}

extension String: ParameterEncoding {

    public func encode(_ urlRequest: URLRequestConvertible, with parameters: Parameters?) throws -> URLRequest {
        var request = try urlRequest.asURLRequest()
        request.httpBody = data(using: .utf8, allowLossyConversion: false)
        return request
    }
}

extension ProgressViewController {
    
    func downloadNicoVideoAndCommentUsingNewAPI(item: NicoVideoItem) -> Promise<Void> {
        sessionManager.retrier = Retrier()
        
        let videoURL = "https://www.nicovideo.jp/watch/\(item.videoId)"
        
        let headers = [
            "Accept": "*/*",
            "Origin": "https://www.nicovideo.jp",
            "Sec-Fetch-Site": "cross-site",
            "Sec-Fetch-Mode": "cors",
            "Sec-Fetch-Dest": "empty",
            "Referer": "https://www.nicovideo.jp/watch/\(item.videoId)",
            "Accept-Encoding": "gzip, deflate, br",
            "Accept-Language": "en-US,en;q=0.9",
            "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.0 Safari/605.1.15"
        ]
        
        return getVideoPage(videoURL: videoURL)
            .then { (videoPageResponse: StringResponse) -> Promise<URL> in
                let videoPage = videoPageResponse.string
                
                item.apiDataJson = try self.getApiDataJson(fromVideoPage: videoPage)
                
                item.name = item.apiDataJson["video"]["title"].stringValue
                item.status = .downloading
                
                self.reloadTableViewData()
                
                return try self.requestVideo(item: item, headers: headers)
            }.then { (savedVideoURL: URL) -> Promise<StringResponse> in
                item.videoFileURL = savedVideoURL
                
                return self.requestComment(item: item, headers: headers)
            }.done { (commentResponse: StringResponse) in
                item.filterFileURL = self.saveComments(jsonString: commentResponse.string, item: item)
            }
    }
    
    private func requestVideo(item: NicoVideoItem, headers: Headers) throws -> Promise<URL> {
        let sessionData = try self.createSessionData(fromApiDataJson: item.apiDataJson)
        let outputDir = self.options.saveDirectory.appendingPathComponent(item.name, isDirectory: true)
        try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true, attributes: nil)
        
        return sessionManager.upload(sessionData, to: "https://api.dmc.nico/api/sessions?_format=json").responseString()
            .then { (sessionResponse: StringResponse) -> Promise<(String, StringResponse)> in
                let contentUri = try self.getContentUri(sessionResponseString: sessionResponse.string, headers: headers)
                return self.sessionManager.request(contentUri, method: .get, headers: headers).responseString().map { (contentUri, $0) }
            }.then { (contentUri: String, contentResponse: StringResponse) -> Promise<(String, StringResponse)> in
                let playlistUri = try self.getPlaylistUri(contentResponseString: contentResponse.string, contentUri: contentUri)
                
                return self.sessionManager.request(playlistUri, method: .get, headers: headers).responseString().map { (playlistUri, $0) }
            }.then { (playlistUri: String, playlistResponse: StringResponse) -> Promise<[DownloadResponse<Data>]> in
                item.tsURLs = try self.getTsUrls(playlistResponseString: playlistResponse.string, playlistUri: playlistUri)
                let downloadPromises = self.createDownloadTSVideoPromises(item: item, outputDir: outputDir, headers: headers)

                return when(fulfilled: downloadPromises.makeIterator(), concurrently: 2)
            }.then { (downloadResponses: [DownloadResponse<Data>]) -> Promise<URL> in
                let concattedVideoPath = self.options.saveDirectory.appendingPathComponent(item.name, isDirectory: false).appendingPathExtension("ts")
                
                return Promise { seal in
                    let _ = concatVideos(inputFilesUrl: outputDir, fileExtension: "ts", outputFileURL: concattedVideoPath) { result in
                        seal.fulfill(concattedVideoPath)
                    }
                }
            }
    }
    
    private func createDownloadTSVideoPromises(item: NicoVideoItem, outputDir: URL, headers: Headers) -> [Promise<DownloadResponse<Data>>] {
        var tsUrlSet = Set(item.tsURLs)
        
        let dest = { (url: URL, urlResponse: HTTPURLResponse) -> (destinationURL: URL, options: DownloadRequest.DownloadOptions) in
            let destURL = outputDir.appendingPathComponent(urlResponse.url!.lastPathComponent)
            return (destURL, [.removePreviousFile])
        }
        let downloadPromises = item.tsURLs.map { (tsUrl: String) -> Promise<DownloadResponse<Data>> in
            let request = self.sessionManager.download(tsUrl, method: .get, headers: headers, to: dest)
            request.validate(statusCode: [200])

            return request.responseData().then { (response: DownloadResponse<Data>) -> Promise<DownloadResponse<Data>> in
                tsUrlSet.remove(tsUrl)
                item.progress = (1 - Double(tsUrlSet.count) / Double(item.tsURLs.count))
                self.reloadTableViewData()
                
                return Promise.value(response)
            }
        }
        
        return downloadPromises
    }
    
    private func requestComment(item: NicoVideoItem, headers: Headers) -> Promise<StringResponse> {
        let apiJsonRequestBody = self.createApiJsonRequestBody(fromApiDataJson: item.apiDataJson)
        
        var h = headers
        h["Content-Type"] = "text/plain;charset=UTF-8"
        h["Content-Length"] = "\(apiJsonRequestBody.count)"
        
        return self.sessionManager.request("https://nmsg.nicovideo.jp/api.json", method: .post, parameters: [:], encoding: apiJsonRequestBody, headers: h).responseString()
    }
    
    private func saveComments(jsonString: String, item: NicoVideoItem) -> URL? {
        do {
            try Comment.saveOriginalComment(
                fromSourceString: jsonString, item: item)
            return try Comment.saveFilterFile(
                fromSourceString: jsonString, item: item)
        } catch {
            print("Error occurred while saving comments")
        }
        
        return nil
    }
    
    private func getVideoPage(videoURL: String) -> Promise<StringResponse> {
        return sessionManager.request(videoURL, method: .get).responseString()
    }
    
    private func getApiDataJson(fromVideoPage videoPage: String) throws -> JSON {
        guard let doc = try? SwiftSoup.parse(videoPage),
            let temp = try? doc.select("div#js-initial-watch-data").first(),
            let apiData = try? temp.attr("data-api-data") else {
            print("Error occurred while parsing.")
            throw NicoError.VideoAPIError
        }
        
        return JSON(parseJSON: apiData)
    }

    private func createSessionData(fromApiDataJson apiDataJson: JSON) throws -> Data {
        let sessionApi = apiDataJson["video"]["dmcInfo"]["session_api"]
        let session = createSession(sessionApi: sessionApi)
        let sessionString = JSON(session).description.split(separator: "\n").joined()
        
        guard let sessionData = sessionString.data(using: .utf8) else {
            throw NicoError.SessionAPIError("Error while encoding session data: \(sessionString)")
        }

        return sessionData
    }
    
    private func createApiJsonRequestBody(fromApiDataJson apiDataJson: JSON) -> String {
        var commentNumPerLeaf = 100;
        
        let duration = apiDataJson["video"]["duration"].floatValue
        let leafCnt = Int(ceil(duration / 60))
        
        if leafCnt * commentNumPerLeaf > maxCommentCnt {
            commentNumPerLeaf = Int(ceil(Double(maxCommentCnt / leafCnt)))
        }
        
        let resFrom: Int
        if leafCnt / 5 > 2 {
            resFrom = 1000
        } else if leafCnt / 5 > 1 {
            resFrom = 500
        } else {
            resFrom = 250
        }
        
        let threadId = apiDataJson["video"]["dmcInfo"]["thread"]["thread_id"]
        let userId = apiDataJson["video"]["dmcInfo"]["user"]["user_id"]
        let userKey = apiDataJson["context"]["userkey"]
        
        return "[{\"ping\":{\"content\":\"rs:0\"}},{\"ping\":{\"content\":\"ps:0\"}},{\"thread\":{\"thread\":\"\(threadId)\",\"version\":\"20090904\",\"fork\":0,\"language\":0,\"user_id\":\"\(userId)\",\"with_global\":1,\"scores\":1,\"nicoru\":3,\"userkey\":\"\(userKey)\"}},{\"ping\":{\"content\":\"pf:0\"}},{\"ping\":{\"content\":\"ps:1\"}},{\"thread_leaves\":{\"thread\":\"\(threadId)\",\"fork\":0,\"language\":0,\"user_id\":\"\(userId)\",\"content\":\"0-\(leafCnt):100,\(resFrom),nicoru:100\",\"scores\":1,\"nicoru\":3,\"userkey\":\"\(userKey)\"}},{\"ping\":{\"content\":\"pf:1\"}},{\"ping\":{\"content\":\"ps:2\"}},{\"thread\":{\"thread\":\"\(threadId)\",\"version\":\"20090904\",\"fork\":2,\"language\":0,\"user_id\":\"\(userId)\",\"with_global\":1,\"scores\":1,\"nicoru\":3,\"userkey\":\"\(userKey)\"}},{\"ping\":{\"content\":\"pf:2\"}},{\"ping\":{\"content\":\"ps:3\"}},{\"thread_leaves\":{\"thread\":\"\(threadId)\",\"fork\":2,\"language\":0,\"user_id\":\"\(userId)\",\"content\":\"0-\(leafCnt):25,nicoru:100\",\"scores\":1,\"nicoru\":3,\"userkey\":\"\(userKey)\"}},{\"ping\":{\"content\":\"pf:3\"}},{\"ping\":{\"content\":\"rf:0\"}}]"
    }
    
    private func getContentUri(sessionResponseString: String, headers: Headers) throws -> String {
        guard let dataFromString = sessionResponseString.data(using: .utf8, allowLossyConversion: false),
            let sessionJson = try? JSON(data: dataFromString) else {
            throw NicoError.SessionAPIError("Error while parsing session json response")
        }
        return sessionJson["data"]["session"]["content_uri"].stringValue
    }

    private func getPlaylistUri(contentResponseString: String, contentUri: String) throws -> String {
        guard let r = contentUri.range(of: "master"),
              let playlistPostfix = contentResponseString.split(separator: "\n").last else {
            throw NicoError.SessionAPIError("Error while parsing playlist URI from: \(contentResponseString)")
        }

        let prefixUri = String(contentUri[..<r.lowerBound])
        return "\(prefixUri)\(playlistPostfix)"
    }

    private func getTsUrls(playlistResponseString: String, playlistUri: String) throws -> [String] {
        let tsLines = playlistResponseString.split(separator: "\n").filter { $0.contains(".ts?") }
        
        guard tsLines.count > 0,
              let r = playlistUri.range(of: "/ts/") else {
            throw NicoError.SessionAPIError("Error while parsing playlist: \(playlistResponseString)")
        }
        let playlistPrefixUri = String(playlistUri[..<r.upperBound])

        return tsLines.map { "\(playlistPrefixUri)\($0)" }
    }

    private func createSession(sessionApi: JSON) -> [String: Any] {
        let isHlsEnabled = sessionApi["protocols"].arrayValue.contains { $0.stringValue == "hls" }
        let protocolName = isHlsEnabled ? "hls" : ["http", "storyboard"].first { p in sessionApi["protocols"].arrayValue.contains { $0.stringValue == p } }!
        
        var session: [String: Any] = [
            "recipe_id": sessionApi["recipe_id"].stringValue,
            "content_id": sessionApi["content_id"].stringValue,
            "content_type": "movie",
            "content_src_id_sets": [[
                "content_src_ids": [[
                    "src_id_to_mux": [
                        "video_src_ids": sessionApi["videos"].arrayValue.map(String.init),
                        "audio_src_ids": sessionApi["audios"].arrayValue.map(String.init)
                    ]
                ]]
            ]],
            "timing_constraint": "unlimited",
            "keep_method": [
                "heartbeat": [
                    "lifetime": sessionApi["heartbeat_lifetime"].intValue
                ]
            ],
            "content_uri": "",
            "session_operation_auth": [
                "session_operation_auth_by_signature": [
                    "token": sessionApi["token"].stringValue,
                    "signature": sessionApi["signature"].stringValue
                ]
            ],
            "content_auth": [
                "auth_type": sessionApi["auth_types"][protocolName],
                "content_key_timeout": sessionApi["content_key_timeout"].intValue,
                "service_id": "nicovideo",
                "service_user_id": sessionApi["service_user_id"].stringValue
            ],
            "client_info": [
                "player_id": sessionApi["player_id"].stringValue
            ],
            "priority": sessionApi["priority"].doubleValue
        ]
        
        // Splitted into different session since stupid Swift compiler can't even handle nested dictionary
        session["protocol"] = [
            "name": isHlsEnabled ? "http" : protocolName,
            "parameters": [
                "http_parameters": [
                    "parameters": [
                        "hls_parameters": [
                            "segment_duration": 6000,
                            "transfer_preset": sessionApi["transfer_presets"].arrayValue.first?.string ?? "",
                            "use_ssl": "yes",
                            "use_well_known_port": "yes"
                        ]
                    ]
                ]
            ]
        ]
        
        if let maxContentCount = sessionApi["max_content_count"].string,
            var contentAuth = session["content_auth"] as? [String: Any?] {
            contentAuth["max_content_count"] = Int(maxContentCount)!
        }
        
        return ["session": session]
    }
}
