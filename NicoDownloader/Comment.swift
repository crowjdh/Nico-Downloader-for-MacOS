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

enum CommentColor: String, Iterable {
    case white, red, pink, orange, yellow, green, cyan, blue, purple, black,
    white2, niconicowhite, red2, truered, pink2, orange2, passionorange,
    yellow2, madyellow, green2, elementalgreen, cyan2, blue2, marineblue,
    purple2, nobleviolet, black2
}

struct Comment {
    let no: Int
    let vpos: Int
    let size: Size
    let position: Position
    let color: CommentColor
    let comment: String
}

extension Comment {
    static func fromXml(_ xml: String) -> [Comment]? {
        guard let doc = Kanna.XML(xml: xml, encoding: .utf8) else {
//            reject(NicoError.FetchVideoIdsError("Malformed xml"))
            return nil
        }
        var comments = [Comment]()
        let chatXmls = doc.xpath("//chat")
        for chatXml in chatXmls {
            guard let no = chatXml.at_xpath("@no")?.text,
                let vpos = chatXml.at_xpath("@vpos")?.text,
                let comment = chatXml.text else {
                    continue
            }
            let command = chatXml.at_xpath("@mail")?.text ?? ""
            let commandElems = command.components(separatedBy: " ")
            
            let position = commandElems.flatMap { Position.init(rawValue: $0) }.first ?? Position.naka
            let size = commandElems.flatMap { Size.init(rawValue: $0) }.first ?? Size.medium
            let color = commandElems.flatMap { CommentColor.init(rawValue: $0) }.first ?? CommentColor.white
            
            comments.append(Comment(no: Int(no)!, vpos: Int(vpos)!, size: size,
                                    position: position, color: color,
                                    comment: comment))
        }
        return comments
    }
}
