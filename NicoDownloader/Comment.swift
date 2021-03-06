//
//  Comment.swift
//  NicoDownloader
//
//  Created by Jeong on 2017. 2. 28..
//  Copyright © 2017년 Jeong. All rights reserved.
//

import Foundation
import Kanna
import SwiftyJSON

let videoExtensions: [String] = mimeTypes.filter { topLevelMimeTypeOf(mimeType: $0.value) == "video" }.flatMap { $0.0 }
let commentExtension = "comment"
let filterExtension = "filter"

enum CommentError: Error {
    case XMLParseError
    case JSONParseError
    case RawSourceError
}

enum Size: String, Iterable {
    case small
    case medium
    case big
    
    var idx: Int {
        switch self {
        case .small:
            return 0
        case .medium:
            return 1
        case .big:
            return 2
        }
    }
    
    func videoHeightDenominator() -> Int {
        return Size.videoHeightDenominator(ofSize: self)
    }
    
    static func fromIndex(_ idx: Int) -> Size? {
        switch idx {
        case 0:
            return .small
        case 1:
            return .medium
        case 2:
            return .big
        default:
            return nil
        }
    }
    
    static func videoHeightDenominator(ofSize size: Size?) -> Int {
        guard let size = size else {
            return 44
        }
        switch size {
        case .small:
            return 22
        case .medium:
            return 15
        case .big:
            return 11
        }
    }
    
}

enum Position: String, Iterable {
    case ue
    case shita
    case naka
}

enum NGLevel: Int {
    case none = 0, low, mid, high
    
    static let defaultValue = NGLevel.mid
    
    var validScoreRange: ClosedRange<Int> {
        switch self {
        case .none:
            return Int.min...0
        case .low:
            return -10000+1...0
        case .mid:
            return -4800+1...0
        default:
            return -1000+1...0
        }
    }
    
    func shouldDisplay(score: Int) -> Bool {
        return validScoreRange.contains(score)
    }
    
    func shouldNotDisplay(score: Int) -> Bool {
        return !shouldDisplay(score: score)
    }
    
    static func from(value: Int) -> NGLevel? {
        return NGLevel(rawValue: value)
    }
    
    static func load() -> NGLevel {
        guard let rawNgLevel = UserDefaults.standard.value(forKey: "ngLevel") as? Int,
            let ngLevel = NGLevel(rawValue: rawNgLevel) else {
                return defaultValue
        }
        return ngLevel
    }
    
    static func save(ngLevel: NGLevel) {
        UserDefaults.standard.set(ngLevel.rawValue, forKey: "ngLevel")
    }
}

func nicoColorToHex(hexColor: String) -> String? {
    switch hexColor {
    case "white": return "#FFFFFF"
    case "red": return "#FF0000"
    case "pink": return "#FF8080"
    case "orange": return "#FFC000"
    case "yellow": return "#FFFF00"
    case "green": return "#00FF00"
    case "cyan": return "#00FFFF"
    case "blue": return "#0000FF"
    case "purple": return "#C000FF"
    case "black": return "#000000"
    case "white2": return "#CCCC99"
    case "niconicowhite": return "#CCCC99"
    case "red2": return "#CC0033"
    case "truered": return "#CC0033"
    case "pink2": return "#FF33CC"
    case "orange2": return "#FF6600"
    case "passionorange": return "#FF6600"
    case "yellow2": return "#999900"
    case "madyellow": return "#999900"
    case "green2": return "#00CC66"
    case "elementalgreen": return "#00CC66"
    case "cyan2": return "#00CCCC"
    case "blue2": return "#3399FF"
    case "marineblue": return "#3399FF"
    case "purple2": return "#6633CC"
    case "nobleviolet": return "#6633CC"
    case "black2": return "#666666"
    default: return NSColor(rgba: hexColor) != nil ? hexColor : nil
    }
}

struct Comment {
    static let maximumLine = 11
    
    let no: Int
    let vpos: Int
    let size: Size
    let position: Position
    let color: String
    let comment: String
    let videoResolution: VideoResolution
    var line: Int!
    
    var startTimeSec: Float {
        return max(0, Float(vpos)/100.0 - (position == .naka ? 1.5 : 0))
    }
    
    init(no: Int, vpos: Int, size: Size, position: Position, color: String, comment: String, videoResolution: VideoResolution) {
        self.no = no
        self.vpos = vpos
        self.size = size
        self.position = position
        self.color = color
        self.comment = comment
        self.videoResolution = videoResolution
    }
}

protocol CommentConvertable {
    associatedtype T
    
    var score: Int? { get }
    var no: Int? { get }
    var vpos: Int? { get }
    var deleted: Int? { get }
    var position: Position { get }
    var size: Size { get }
    var colorHex: String { get }
    var content: String? { get }
    var commands: [String]? { get }
    
    static func from(rawConvertable: T) -> Self
}

extension CommentConvertable {
    var position: Position {
        commands?.compactMap { Position.init(rawValue: $0) }.first ?? Position.naka
    }
    var size: Size {
        commands?.compactMap { Size.init(rawValue: $0) }.first ?? Size.medium
    }
    var colorHex: String {
        commands?.compactMap { nicoColorToHex(hexColor: $0) }.first ?? nicoColorToHex(hexColor: "white")!
    }
}

struct XMLComment: CommentConvertable {
    
    typealias T = Kanna.XMLElement
    
    var score: Int? {
        integer(atPath: "@score")
    }
    var no: Int? {
        integer(atPath: "@no")
    }
    var vpos: Int? {
        integer(atPath: "@vpos")
    }
    var deleted: Int? {
        integer(atPath: "@deleted")
    }
    var content: String? {
        xmlElement.text
    }
    var commands: [String]? {
        let command = string(atPath: "@mail") ?? ""
        return command.components(separatedBy: " ")
    }
    
    private var xmlElement: Kanna.XMLElement
    
    init(fromXmlElement xmlElement: Kanna.XMLElement) {
        self.xmlElement = xmlElement
    }
    
    static func from(rawConvertable: T) -> Self {
        return XMLComment(fromXmlElement: rawConvertable)
    }
    
    private func integer(atPath path: String) -> Int? {
        guard let contentString = string(atPath: path),
            let contentInt = Int(contentString) else {
            return nil
        }
        return contentInt
    }
    
    private func string(atPath path: String) -> String? {
        return xmlElement.at_xpath(path)?.text
    }
}

struct JSONComment: CommentConvertable {
    
    typealias T = JSON
    
    var score: Int? {
        jsonElement["score"].int
    }
    var no: Int? {
        jsonElement["no"].int
    }
    var vpos: Int? {
        jsonElement["vpos"].int
    }
    var deleted: Int? {
        jsonElement["deleted"].int
    }
    var content: String? {
        jsonElement["content"].string
    }
    var commands: [String]? {
        let command = jsonElement["mail"].string ?? ""
        return command.components(separatedBy: " ")
    }
    
    private var jsonElement: JSON
    
    init(fromJsonElement jsonElement: JSON) {
        self.jsonElement = jsonElement
    }
    
    static func from(rawConvertable: T) -> Self {
        return JSONComment(fromJsonElement: rawConvertable)
    }
}

extension Comment {
    
    static func parseXml(_ xml: String, videoResolution: VideoResolution, parsed: (Comment, Bool) -> Void) throws {
        guard let doc = try? Kanna.XML(xml: xml, encoding: .utf8) else {
            throw CommentError.XMLParseError
        }
        let chatXmls = doc.xpath("//chat")
        guard chatXmls.count > 0 else {
            throw CommentError.XMLParseError
        }
        
        parse(chatXmls, videoResolution: videoResolution, adapter: XMLComment.self) { index, comment in
            parsed(comment, index >= chatXmls.count - 1)
        }
    }
    
    static func parseJson(_ jsonString: String, videoResolution: VideoResolution, parsed: (Comment, Bool) -> Void) throws {
        let json = JSON(parseJSON: jsonString)
        guard let chats = json.array?.filter({ $0["chat"].exists() }).compactMap({ $0["chat"] }) else {
            throw CommentError.JSONParseError
        }
        
        parse(chats, videoResolution: videoResolution, adapter: JSONComment.self) { index, comment in
            parsed(comment, index >= chats.count - 1)
        }
    }
    
    static func parse<T: CommentConvertable, U: Sequence>(_ rawComments: U, videoResolution: VideoResolution, adapter: T.Type, each: (Int, Comment) -> Void) {
        for (index, element) in rawComments.enumerated() {
            guard let element = element as? T.T else {
                continue
            }
            let convrtable = adapter.from(rawConvertable: element)
            guard let comment = parseElement(commentConvertable: convrtable, videoResolution: videoResolution) else {
                continue
            }
            
            each(index, comment)
        }
    }
    
    static func parseElement<T: CommentConvertable>(commentConvertable: T, videoResolution: VideoResolution) -> Comment? {
        let ngLevel = NGLevel.load()
        if let score = commentConvertable.score,
            ngLevel.shouldNotDisplay(score: score) {
            return nil
        }
        guard let no = commentConvertable.no,
              let vpos = commentConvertable.vpos,
              commentConvertable.deleted == nil,
              let comment = commentConvertable.content else {
            return nil
        }
        
        return Comment(no: no,
                       vpos: vpos,
                       size: commentConvertable.size,
                       position: commentConvertable.position,
                       color: commentConvertable.colorHex,
                       comment: comment,
                       videoResolution: videoResolution)
    }
    
    static func from(_ rawComments: String, videoResolution: VideoResolution) throws -> [Comment] {
        var comments: [Comment]? = nil
        comments = try? fromXml(rawComments, videoResolution: videoResolution)
        if comments == nil {
            comments = try? fromJson(rawComments, videoResolution: videoResolution)
        }
        
        if let comments = comments {
            return comments
        }
        
        throw CommentError.RawSourceError
    }
    
    static func fromXml(_ xml: String, videoResolution: VideoResolution) throws -> [Comment] {
        var comments = [Comment]()
        try parseXml(xml, videoResolution: videoResolution) { comment, _ in comments.append(comment) }
        return comments
    }
    
    static func fromJson(_ jsonString: String, videoResolution: VideoResolution) throws -> [Comment] {
        var comments = [Comment]()
        try parseJson(jsonString, videoResolution: videoResolution) { comment, _ in comments.append(comment) }
        return comments
    }
}

extension Comment {
    
    private static func createDirectory(url: URL) throws {
        try FileManager.default.createDirectory(
            at: url, withIntermediateDirectories: true, attributes: nil)
    }
    
    static func saveOriginalComment(fromSourceString sourceString: String, item: NicoItem) throws {
        try createDirectory(url: item.videoFileURL.filterFileRootURL)
        
        let fileURL = item.videoFileURL.commentFileURL
        try sourceString.write(to: fileURL, atomically: false, encoding: String.Encoding.utf8)
    }
    
    static func saveFilterFile(fromCommentFile commentFileURL: URL, item: FilterItem) throws -> URL? {
        guard let videoFileURL = item.videoFileURL else {
            return nil
        }
        let sourceString = try String(contentsOf: commentFileURL, encoding: .utf8)
        return try saveFilterFile(fromSourceString: sourceString, videoFileURL: videoFileURL)
    }
    
    static func saveFilterFile(fromSourceString sourceString: String, item: NicoItem) throws -> URL {
        return try saveFilterFile(fromSourceString: sourceString, videoFileURL: item.videoFileURL)
    }
    
    static func saveFilterFile(fromSourceString sourceString: String,
                               videoFileURL: URL) throws -> URL {
        try createDirectory(url: videoFileURL.filterFileRootURL)
        let filterURL = videoFileURL.filterFileURL
        
        try "[in]fps=60[tmp],\n".write(to: filterURL, atomically: false, encoding: String.Encoding.utf8)
        let filterFileHandle = try FileHandle(forWritingTo: filterURL)
        filterFileHandle.seekToEndOfFile()
        
        var resolution = getVideoResolution(inputFilePath: videoFileURL.absoluteString.removingPercentEncoding!)!
        // Disabled due to large output file size
//        if resolution.1 < 480 {
//            resolution.0 = (resolution.0 * 480) / resolution.1
//            resolution.1 = 480
//            filterFileHandle.write("[tmp]scale=width=\(resolution.0):height=\(resolution.1)[tmp],\n".data(using: String.Encoding.utf8, allowLossyConversion: false)!)
//        }
        var padding = (0, 0)
        if resolution.0 * 9 < resolution.1 * 16 {
            // Enlarge width
            padding.0 = resolution.1 * 16 / 9 - resolution.0
            resolution.0 += padding.0
        }
        else {
            padding.1 = resolution.0 * 9 / 16 - resolution.1
            resolution.1 += padding.1
        }
        filterFileHandle.write("[tmp]pad=\(resolution.0):\(resolution.1):\(padding.0 / 2):\(padding.1 / 2)[tmp],\n".data(using: String.Encoding.utf8, allowLossyConversion: false)!)
        
        let guessedLineHeight = resolution.1 / Comment.maximumLine
        
        let rawComments = try Comment.from(sourceString, videoResolution: resolution).sorted { lhs, rhs in
            lhs.vpos != rhs.vpos ? lhs.vpos < rhs.vpos : lhs.no < rhs.no
        }
        let comments = Comment.assignLinesToComments(comments: rawComments, videoWidth: Float(resolution.0))
        
        // TODO: Comment heights are different by comment sizes(0.5cm*?Lines, 0.75cm*11Lines, 1cm*8Lines)
        for (idx, comment) in comments.enumerated() {
            // TODO: Add empty space to fit aspect ratio of embedded player(possibly on each side)
            // TODO: Adjust start time of comments at the end of video(show little bit earlier)
            let yIdx = comment.normalizedLine
            
            let alignVariant = "-(\(guessedLineHeight)-lh)/2"
            let escapedComment = comment.comment.unicodeScalars.map { scalar in
                switch scalar {
                    case "\\":
                        return "\\\\\\\\"
                case "'":
                    return "'\\\\\\\''"
                case ":":
                    return "\\\\\\:"
                default:
                    return String(scalar)
                }
            }.joined()
            let x = comment.position == .naka ? ":x=w-max(t-\(comment.startTimeSec)\\,0)*(w+tw)/\(comment.duration)" : ":x=(w-tw)/2"
            var line = "[tmp]drawtext=fontsize=\(comment.fontSize):fontcolor=\(comment.color):fontfile=\(comment.fontPath)" + x + ":y=\(guessedLineHeight)*(\(yIdx + 1)-\(Comment.maximumLine)*floor(\(yIdx)/\(Comment.maximumLine)))-lh" + alignVariant + ":text='\(escapedComment)':borderw=1:bordercolor=#333333:shadowx=1.5:shadowcolor=#333333:enable='between(t, \(comment.startTimeSec), \(comment.startTimeSec + comment.duration))'[tmp],\n"
            
            // Remove ",\n" for last item
            if idx == comments.count - 1 {
                let range = line.index(line.endIndex, offsetBy: -7) ..< line.endIndex
                line.removeSubrange(range)
                line.append("[out]")
            }
            filterFileHandle.write(line.data(using: String.Encoding.utf8, allowLossyConversion: false)!)
        }
        
        filterFileHandle.closeFile()
        
        return filterURL
    }
    
    static func assignLinesToComments(comments: [Comment], videoWidth: Float) -> [Comment] {
        let flowingComments = assignLinesToComments(comments: comments, position: .naka, videoWidth: videoWidth)
        let ueComments = assignLinesToComments(comments: comments, position: .ue, videoWidth: videoWidth)
        let shitaComments = assignLinesToComments(comments: comments, position: .shita, videoWidth: videoWidth)
        var comments: [Comment] = []
        comments.append(contentsOf: flowingComments)
        comments.append(contentsOf: ueComments)
        comments.append(contentsOf: shitaComments)
        return comments
    }
    
    static func assignLinesToComments(comments origianlComments: [Comment], position: Position, videoWidth: Float) -> [Comment] {
        var comments = origianlComments.filter { $0.position == position }
        
        var commentsOnScreen = [Int: Comment]()
        var vacantLines = IndexSet(0..<1000)
        
        for idx in comments.indices {
            let commentToAdd = comments[idx]
            let currentTime = commentToAdd.startTimeSec
            
            /* Clean up & get line number */
            var occupiedLines = IndexSet()
            for line in commentsOnScreen.keys {
                // Force unwrap since we're iterating over keys
                // This might change if "flowingCommentsOnScreen" can be used in multi-threaded environment
                let lastCommentInLine = commentsOnScreen[line]!
                if !lastCommentInLine.isVisible(currentTime: currentTime) {
                    commentsOnScreen.removeValue(forKey: line)
                } else if !lastCommentInLine.canHaveFollowingInSameLine(other: commentToAdd, videoWidth: videoWidth) {
                    /* Store lines which can't have this comment */
                    occupiedLines.insert(line)
                }
            }
            vacantLines.subtract(occupiedLines)
            /* Force unwrap since the number of maximum comments is 1000
             * so there should be at least one vacant line */
            let vacantLine = vacantLines.first!
            // Restore vacant lines Set for later use
            vacantLines.formUnion(occupiedLines)
            
            comments[idx].line = vacantLine
            commentsOnScreen[vacantLine] = comments[idx]
        }
        
        return comments
    }
}

struct Font {
    let fontFilePath: String
    let fontFamilyName: String
    private let fontWithNoSize: NSFont
    
    init(fontFilePath: String, fontFamilyName: String) {
        self.fontFilePath = fontFilePath
        self.fontFamilyName = fontFamilyName
        self.fontWithNoSize = Font.nsfont(fontFamilyName: fontFamilyName, withSize: Float(0.0))
    }
    
    func contains(content: String) -> Bool {
        return content.rangeOfCharacter(from: fontWithNoSize.coveredCharacterSet.inverted) == nil
    }
    
    func nsfont(withSize fontSize: Float) -> NSFont {
        // TODO: Cache if possible
        return Font.nsfont(fontFamilyName: fontFamilyName, withSize: fontSize)
    }
    
    static func nsfont(fontFamilyName: String, withSize fontSize: Float) -> NSFont {
        return NSFont(name: fontFamilyName, size: CGFloat(fontSize))!
    }
}

extension Comment {
    static let basicFont = Font(
        fontFilePath: Bundle.main.path(forResource: "ヒラギノ角ゴシック W4", ofType: "ttc", inDirectory: "Fonts")!,
        fontFamilyName: "HiraginoSans-W4")
    static let unicodeFont = Font(
        fontFilePath: Bundle.main.path(forResource: "Arial Unicode", ofType: "ttf", inDirectory: "Fonts")!,
        fontFamilyName: "ArialUnicodeMS")
    
    var fontSize: Float {
        let videoHeight = Float(videoResolution.1)
        guard position == .shita || position == .ue else {
            return calculateFontSize(withSize: self.size, videoHeight: videoHeight)
        }
        let videoWidth = Float(videoResolution.0)
        var fontSize: Float! = nil
        var commentWidth: Float = Float(99999)
        var size: Size! = self.size
        
        while size != nil {
            fontSize = calculateFontSize(withSize: size, videoHeight: videoHeight)
            commentWidth = Float(boundingRectSize(withFontSize: fontSize).width)
            if commentWidth < videoWidth || size.idx <= 0 {
                break
            }
            size = Size.fromIndex(size.idx - 1)
        }
        
        if commentWidth > videoWidth {
            fontSize = findBestFontSize(fontSize: fontSize)
        }
        return fontSize
    }
    var duration: Float {
        return position == .naka ? Float(4) : Float(3)
    }
    
    private var boundingRectSize: CGSize {
        return boundingRectSize(withFontSize: fontSize)
    }
    var width: Float {
        return Float(boundingRectSize.width)
    }
    var height: Float {
        return Float(boundingRectSize.height)
    }
    var normalizedLine: Int {
        guard position == .shita else {
            return line
        }
        let lineInScreen = line - Comment.maximumLine * (line / Comment.maximumLine)
        return (Comment.maximumLine - 1) - lineInScreen
    }
    var font: Font {
        let font: Font
        if Comment.basicFont.contains(content: comment) {
            font = Comment.basicFont
        } else {
            font = Comment.unicodeFont
        }
        return font
    }
    var fontPath: String {
        return font.fontFilePath
    }
    
    private func calculateFontSize(withSize: Size, videoHeight: Float) -> Float {
        return videoHeight / Float(withSize.videoHeightDenominator())
    }
    
    private func findBestFontSize(fontSize: Float) -> Float {
        let videoWidth = Float(videoResolution.0)
        var minFontSize = Float(videoResolution.1) / Float(Size.videoHeightDenominator(ofSize: nil))
        var maxFontSize = fontSize
        // FIX:boundingRectSize(withFontSize: Float) gives wrong width
        guard Float(boundingRectSize(withFontSize: minFontSize).width) < videoWidth else {
            var newWidth: Float
            repeat {
                minFontSize -= 1
                newWidth = Float(boundingRectSize(withFontSize: minFontSize).width)
            } while newWidth > videoWidth
            return minFontSize
        }
        var found: Float! = nil
        while true {
            let midFontSize = minFontSize + (maxFontSize - minFontSize) / 2
            let commentWidth = Float(boundingRectSize(withFontSize: midFontSize).width)
            if commentWidth > videoWidth {
                maxFontSize = midFontSize
            } else {
                minFontSize = midFontSize
            }
            if maxFontSize - minFontSize < 3 {
                found = midFontSize
                break
            }
        }
        return found
    }
    
    private func boundingRectSize(withFontSize: Float) -> CGSize {
        let nsText = comment as NSString
        let dict: [NSAttributedString.Key: NSFont] = [NSAttributedString.Key.font: nsfont(withSize: withFontSize)]
        return nsText.size(withAttributes: dict)
    }
    
    func nsfont(withSize fontSize: Float) -> NSFont {
        return font.nsfont(withSize: fontSize)
    }
    
    func isVisible(currentTime: Float) -> Bool {
        return startTimeSec + duration > currentTime
    }
    
    func canHaveFollowingInSameLine(other: Comment, videoWidth: Float) -> Bool {
        guard position == .naka else {
            return false
        }
        let selfTailGotOut = startTimeSec + duration * (width / (videoWidth + width))
        let selfEnd = startTimeSec + duration
        let otherHeadHitsLeft = other.startTimeSec + duration * (videoWidth / (videoWidth + other.width))
        return selfTailGotOut < other.startTimeSec && selfEnd < otherHeadHitsLeft
    }
}
