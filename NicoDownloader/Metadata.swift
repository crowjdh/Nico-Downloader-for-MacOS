//
//  Account.swift
//  NicoDownloader
//
//  Created by Jeong on 2017. 1. 19..
//  Copyright © 2017년 Jeong. All rights reserved.
//

import Foundation

struct Account {
    let email: String
    let password: String
}

struct Options {
    let mylistID: String
    var range: ClosedRange<Int>? = nil
    
    init(mylistID: String) {
        self.mylistID = mylistID
    }
}
