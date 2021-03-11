//
//  XPC.swift
//  PingHelper
//
//  Created by Jacob Greenfield on 3/7/21.
//

import Foundation

@objc protocol PingHelperProtocol {
    func keepAlive(canceled: @escaping () -> Void)
    func resumePing(base: Int, args: [String])
    func cancelPing()
}

@objc protocol PingReverseProtocol {
    func gotPing(number: Int, ping: Double, success: Bool)
}

let helperInterface = NSXPCInterface(with: PingHelperProtocol.self)
let reverseInterface = NSXPCInterface(with: PingReverseProtocol.self)

struct PingResult {
    let number: Int
    let ping: Double
    let success: Bool
}