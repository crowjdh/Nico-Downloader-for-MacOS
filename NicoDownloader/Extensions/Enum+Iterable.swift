//
//  Enum+Iterable.swift
//  NicoDownloader
//
//  Created by Jeong on 2017. 3. 2..
//  Copyright © 2017년 Jeong. All rights reserved.
//

import Foundation

protocol Iterable {}
extension RawRepresentable where Self: RawRepresentable {
    
    static func iterateEnum<T: Hashable>(_: T.Type) -> AnyIterator<T> {
        var i = 0
        return AnyIterator {
            let next = withUnsafePointer(to: &i) {
                $0.withMemoryRebound(to: T.self, capacity: 1) { $0.pointee }
            }
            if next.hashValue != i { return nil }
            i += 1
            return next
        }
    }
}

extension Iterable where Self: RawRepresentable, Self: Hashable {
    static var hashValues: AnyIterator<Self> {
        get {
            return iterateEnum(self)
        }
    }
    
    static var rawValues: [Self.RawValue] {
        get {
            return hashValues.map({$0.rawValue})
        }
    }
}
