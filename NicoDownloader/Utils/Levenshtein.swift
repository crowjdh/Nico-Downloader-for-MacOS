//
//  SwiftyLevenshtein.swift
//  Levenshtein distance algorithm written in Swift 2.2. Both a slow and highly optimized version are included.
//
//  Created by Mark Hamilton on 3/31/16.
//  Copyright © 2016 dryverless. (http://www.dryverless.com)
// 
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
// 
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
// 
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
// 

import Foundation

public func min3(a: Int, b: Int, c: Int) -> Int {
    return min( min(a, c), min(b, c))
}

public extension String {
    
    subscript(subsIdx: Int) -> Character {
        return self[index(startIndex, offsetBy: subsIdx)]
    }
    
    subscript(range: Range<Int>) -> String {
        let char0 = index(startIndex, offsetBy: range.lowerBound)
        let charN = index(startIndex, offsetBy: range.upperBound)
        
//        let a = self[char0..<charN]
        
        return String(self[char0..<charN])
        
    }
    
}

public struct Array2D {
    
    var columns: Int
    var rows: Int
    var matrix: [Int]
    
    
    init(columns: Int, rows: Int) {
        self.columns = columns
        self.rows = rows
        matrix = Array(repeating: 0, count: columns*rows)
    }
    
    subscript(column: Int, row: Int) -> Int {
        
        get {
            
            return matrix[columns * row + column]
            
        }
        
        set {
            
            matrix[columns * row + column] = newValue
            
        }
        
    }
    
    func columnCount() -> Int {
        
        return self.columns
        
    }
    
    func rowCount() -> Int {
        
        return self.rows
        
    }
}

public func levenshtein(source: String, target targetString: String) -> Int {
    
    let targetLength = targetString.count
    let sourceLength = source.count
    guard targetLength > 0 && sourceLength > 0 else { return max(targetLength, sourceLength) }
    
    let source = Array(source.unicodeScalars)
    let target = Array(targetString.unicodeScalars)
    
    var distance = Array2D(columns: sourceLength + 1, rows: targetLength + 1)
    
    for x in 1...sourceLength {
        
        distance[x, 0] = x
        
    }
    
    for y in 1...targetLength {
        
        distance[0, y] = y
        
    }
    
    for x in 1...sourceLength {
        
        for y in 1...targetLength {
            
            if source[x - 1] == target[y - 1] {
                
                // no difference
                distance[x, y] = distance[x - 1, y - 1]
                
            } else {
                
                distance[x, y] = min3(
                    
                    // deletions
                    a: distance[x - 1, y] + 1,
                    // insertions
                    b: distance[x, y - 1] + 1,
                    // substitutions
                    c: distance[x - 1, y - 1] + 1
                    
                )
                
            }
            
        }
        
    }
    
    return distance[source.count, target.count]
    
}

public extension String {
    var length: Int {
        return count
    }
    
    func levenshteinDistance(between target: String) -> Int {
        return levenshtein(source: self, target: target)
    }
    
    func levenshteinPortion(between target: String) -> Double {
        guard self.length > 0 && target.length > 0 else { return Double(max(self.length, target.length)) }
        let distance = levenshtein(source: self, target: target)
        return Double(distance) / Double(max(self.count, target.count))
    }
}
