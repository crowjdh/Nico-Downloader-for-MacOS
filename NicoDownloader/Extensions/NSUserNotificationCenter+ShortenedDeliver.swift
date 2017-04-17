//
//  NSUserNotificationCenter+ShortenedDeliver.swift
//  NicoDownloader
//
//  Created by Jeong on 2017. 4. 16..
//  Copyright © 2017년 Jeong. All rights reserved.
//

import Foundation

typealias NotificationConfigureClosure = ((NSUserNotification) -> Void)

extension NSUserNotificationCenter {
    class func notifyTaskDone(config: NotificationConfigureClosure) {
        let notification = NSUserNotification()
        
        notification.soundName = NSUserNotificationDefaultSoundName
        
        config(notification)
        
        NSUserNotificationCenter.default.deliver(notification)
    }
}
