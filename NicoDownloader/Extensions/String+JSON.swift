//
//  String+JSON.swift
//  NicoDownloader
//
//  Created by Jeong on 2017. 10. 18..
//  Copyright © 2017년 Jeong. All rights reserved.
//

import Foundation

extension String {
    
    func convertToDictionary() -> [String: Any]? {
        if let data = data(using: .utf8) {
            do {
                return try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
            } catch {
                print(error.localizedDescription)
            }
        }
        return nil
    }
}
