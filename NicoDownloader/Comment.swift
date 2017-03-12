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
    static let duration = Float(4)
    
    let no: Int
    let vpos: Int
    let size: Size
    let position: Position
    let color: String
    let comment: String
    
    var startTimeSec: Float {
        return Float(vpos)/100.0
    }
    var line: Int!
    
    init(no: Int, vpos: Int, size: Size, position: Position, color: String, comment: String) {
        self.no = no
        self.vpos = vpos
        self.size = size
        self.position = position
        self.color = color
        self.comment = comment
    }
    
    // TODO: Calculate est - et(if tw == width/4sec, then est - et == 1sec)
    func canHaveFollowingInSameLine(other: Comment) -> Bool {
        let selfEnd = startTimeSec + Comment.duration
        let otherHeadHitsLeft = other.startTimeSec + 2.5
        return selfEnd < otherHeadHitsLeft
    }
}

extension Comment {
    static func parseXml(_ xml: String, parsed: (Comment, Bool) -> Void) {
        guard let doc = Kanna.XML(xml: xml, encoding: .utf8) else {
            return
        }
        let chatXmls = doc.xpath("//chat")
        for (index, chatXml) in chatXmls.enumerated() {
            guard let no = chatXml.at_xpath("@no")?.text,
                let vpos = chatXml.at_xpath("@vpos")?.text,
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
                           comment: comment), index >= chatXmls.count-1)
        }
    }
    
    static func fromXml(_ xml: String) -> [Comment] {
        var comments = [Comment]()
        parseXml(xml) { comments.append($0.0) }
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
        try "".write(to: filterURL, atomically: false, encoding: String.Encoding.utf8)
        
        let filterFileHandle = try FileHandle(forWritingTo: filterURL)
        filterFileHandle.seekToEndOfFile()
        
        let rawComments = Comment.fromXml(xmlString).sorted { $0.0.vpos < $0.1.vpos }
        let comments = Comment.assignLinesToComments(comments: rawComments)
        
        for (idx, comment) in comments.enumerated() {
            // TODO: Add empty space to fit aspect ratio of embedded player(possibly on each side)
            let yIdx = comment.line!
            
            var line = "drawtext=fontsize=20:fontcolor=\(comment.color):fontfile=/Users/jeong/Dev/etc/ffmpeg/playground/fonts/ja_.ttc:x=w-max(t-\(comment.startTimeSec)\\,0)*(w+tw)/\(Comment.duration):y=25*(\(yIdx)-floor(h/25)*floor(\(yIdx)/(floor(h/25))))+10:text='\(comment.comment)':enable='between(t, \(comment.startTimeSec), \(comment.startTimeSec + Comment.duration))',\n"
            
            // Remove ",\n" for last item
            if idx == comments.count - 1 {
                let range = line.index(line.endIndex, offsetBy: -2) ..< line.endIndex
                line.removeSubrange(range)
            }
            filterFileHandle.write(line.data(using: String.Encoding.utf8, allowLossyConversion: false)!)
        }
        
        filterFileHandle.closeFile()
        
        return filterURL
    }
    
    static func assignLinesToComments(comments: [Comment]) -> [Comment] {
        var flowingComments = comments.filter { $0.position == .naka }
//        let fixedComments = comments.filter { $0.position != .naka }
        
        var flowingCommentsOnScreen = [Int: Comment]()
        var vacantLines = IndexSet(0..<1000)
        
        for idx in flowingComments.indices {
            let commentToAdd = flowingComments[idx]
            let currentTime = commentToAdd.startTimeSec
            
            /* Clean up & get line number */
            var occupiedLines = IndexSet()
            for line in flowingCommentsOnScreen.keys {
                // Force unwrap since we're iterating over keys
                // This might change if "flowingCommentsOnScreen" can be used in multi-threaded environment
                let lastCommentInLine = flowingCommentsOnScreen[line]!
                let hasLastCommentGone = lastCommentInLine.startTimeSec + Comment.duration < currentTime
                if hasLastCommentGone {
                    flowingCommentsOnScreen.removeValue(forKey: line)
                } else if !lastCommentInLine.canHaveFollowingInSameLine(other: commentToAdd) {
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
            
            flowingComments[idx].line = vacantLine
            flowingCommentsOnScreen[vacantLine] = flowingComments[idx]
        }
        
        return flowingComments
    }
}
