//
//  Date+XMLPubDate.swift
//  NicoDownloader
//
//  Created by Jeong on 2017. 1. 19..
//  Copyright © 2017년 Jeong. All rights reserved.
//

import Foundation

extension DateFormatter {
    
    class func from(pubdateString: String) -> Date? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss ZZ"
        dateFormatter.locale = Locale(identifier: "en-US")
        dateFormatter.timeZone = TimeZone(abbreviation: "UTC")
        return dateFormatter.date(from: pubdateString)
    }
}
