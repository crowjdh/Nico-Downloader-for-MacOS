//
//  PowerManager.swift
//  NicoDownloader
//
//  Created by Jeong on 2017. 1. 29..
//  Copyright © 2017년 Jeong. All rights reserved.
//

import CoreFoundation
import Foundation
import IOKit.pwr_mgt

let kIOPMAssertionTypeNoDisplaySleep = "PreventUserIdleDisplaySleep" as CFString

class PowerManager {
    
    var powerAssertion: IOReturn = -100
    var powerId: IOPMAssertionID = IOPMAssertionID(0)
    
    func preventSleep(time: NSInteger = 0) {
        if powerAssertion == kIOReturnSuccess {
            NSLog("Sleep already prevented; releasing existing assertion first.")
            releaseSleepAssertion()
        }
        
        powerAssertion = IOPMAssertionCreateWithName(
            kIOPMAssertionTypeNoDisplaySleep,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "Keep screen on for set time" as CFString!,
            &powerId
        )
        
        if powerAssertion == kIOReturnSuccess {
            if time != 0 {
                NSLog("Disable screen sleep for %i minute(s)", time)
            } else {
                NSLog("Disable screen sleep indefinitely")
            }
        }
    }
    
    func releaseSleepAssertion() {
        NSLog("Enable display sleep")
        IOPMAssertionRelease(powerId)
    }
    
}
