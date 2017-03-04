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
    let no: Int
    let vpos: Int
    let size: Size
    let position: Position
    let color: String
    let comment: String
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
