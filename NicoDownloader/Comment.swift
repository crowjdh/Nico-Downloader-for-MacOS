//
//  Comment.swift
//  NicoDownloader
//
//  Created by Jeong on 2017. 2. 28..
//  Copyright © 2017년 Jeong. All rights reserved.
//

import Foundation
import Kanna

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
        return Float(vpos)/100.0
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

extension Comment {
    static func parseXml(_ xml: String, videoResolution: VideoResolution, parsed: (Comment, Bool) -> Void) {
        guard let doc = Kanna.XML(xml: xml, encoding: .utf8) else {
            return
        }
        let chatXmls = doc.xpath("//chat")
        for (index, chatXml) in chatXmls.enumerated() {
            guard let no = chatXml.at_xpath("@no")?.text,
                let vpos = chatXml.at_xpath("@vpos")?.text,
                chatXml.at_xpath("@deleted") == nil,
                let comment = chatXml.text else {
                    continue
            }
            let command = chatXml.at_xpath("@mail")?.text ?? ""
            let commandElems = command.components(separatedBy: " ")
            
            let position = commandElems.flatMap { Position.init(rawValue: $0) }.first ?? Position.naka
            let size = commandElems.flatMap { Size.init(rawValue: $0) }.first ?? Size.medium
            let colorHex = commandElems.flatMap { nicoColorToHex(hexColor: $0) }.first ?? nicoColorToHex(hexColor: "white")!
            
            parsed(Comment(no: Int(no)!, vpos: Int(vpos)!, size: size,
                           position: position, color: colorHex,
                           comment: comment, videoResolution: videoResolution),
                   index >= chatXmls.count-1)
        }
    }
    
    static func fromXml(_ xml: String, videoResolution: VideoResolution) -> [Comment] {
        var comments = [Comment]()
        parseXml(xml, videoResolution: videoResolution) { comments.append($0.0) }
        return comments
    }
}

extension Comment {
    static let commentExtension = "comment"
    
    private static func createDirectory(ofItem item: Item, at directory: URL) throws -> URL {
        let dirURL = directory.appendingPathComponent(item.name, isDirectory: true)
        try FileManager.default.createDirectory(
            at: dirURL, withIntermediateDirectories: true, attributes: nil)
        return dirURL
    }
    
    static func saveOriginalComment(fromXmlString xmlString: String, item: Item, directory: URL) throws {
        let dirURL = try createDirectory(ofItem: item, at: directory)
        let fileURL = dirURL.appendingPathComponent("original").appendingPathExtension(commentExtension)
        try xmlString.write(to: fileURL, atomically: false, encoding: String.Encoding.utf8)
    }
    
    static func saveFilterFile(fromXmlString xmlString: String, item: Item, directory: URL) throws -> URL {
        let dirURL = try createDirectory(ofItem: item, at: directory)
        let filterURL = dirURL.appendingPathComponent("filter").appendingPathExtension(commentExtension)
        try "[in]fps=60[tmp],\n".write(to: filterURL, atomically: false, encoding: String.Encoding.utf8)
        
        let filterFileHandle = try FileHandle(forWritingTo: filterURL)
        filterFileHandle.seekToEndOfFile()
        
        let resolution = getVideoResolution(inputFilePath: item.destinationString)!
        let guessedLineHeight = resolution.1 / Comment.maximumLine
        
        let rawComments = Comment.fromXml(xmlString, videoResolution: resolution).sorted {
            $0.0.vpos != $0.1.vpos ? $0.0.vpos < $0.1.vpos : $0.0.no < $0.1.no
        }
        let comments = Comment.assignLinesToComments(comments: rawComments, videoWidth: Float(resolution.0))
        
        // TODO: Comment heights are different by comment sizes(0.5cm*?Lines, 0.75cm*11Lines, 1cm*8Lines)
        for (idx, comment) in comments.enumerated() {
            // TODO: Add empty space to fit aspect ratio of embedded player(possibly on each side)
            // TODO: Adjust start time of comments at the end of video(show little bit earlier)
            let yIdx = comment.normalizedLine
            
            let alignVariant = "-(\(guessedLineHeight)-lh)/2"
            let escapedComment = comment.comment.replacingOccurrences(of: "'", with: "'\\\\\\\''")
                .replacingOccurrences(of: ":", with: "\\\\\\:")
            let x = comment.position == .naka ? ":x=w-max(t-\(comment.startTimeSec)\\,0)*(w+tw)/\(comment.duration)" : ":x=(w-tw)/2"
            var line = "[tmp]drawtext=fontsize=\(comment.fontSize):fontcolor=\(comment.color):fontfile=\(Comment.fontPath)" + x + ":y=\(guessedLineHeight)*(\(yIdx + 1)-\(Comment.maximumLine)*floor(\(yIdx)/\(Comment.maximumLine)))-lh" + alignVariant + ":text='\(escapedComment)':borderw=1:bordercolor=#333333:shadowx=1.5:shadowcolor=#333333:enable='between(t, \(comment.startTimeSec), \(comment.startTimeSec + comment.duration))'[tmp],\n"
            
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

extension Comment {
    var fontSize: Float {
        let videoHeight = Float(videoResolution.1)
        guard position == .shita else {
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
    static let fontPath = Bundle.main.path(forResource: "ヒラギノ角ゴシック W4", ofType: "ttc", inDirectory: "Fonts")!
    
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
    
    private func calculateFontSize(withSize: Size, videoHeight: Float) -> Float {
        return videoHeight / Float(withSize.videoHeightDenominator())
    }
    
    private func findBestFontSize(fontSize: Float) -> Float {
        let videoWidth = Float(videoResolution.0)
        var minFontSize = Float(videoResolution.1) / Float(Size.videoHeightDenominator(ofSize: nil))
        var maxFontSize = fontSize
        guard Float(boundingRectSize(withFontSize: minFontSize).width) < videoWidth else {
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
        let dict: [String: NSFont] = [NSFontAttributeName: font(withSize: withFontSize)]
        return nsText.size(withAttributes: dict)
    }
    
    func font(withSize fontSize: Float) -> NSFont {
        return NSFont(name: "HiraginoSans-W4", size: CGFloat(fontSize))!
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
