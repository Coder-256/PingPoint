//
//  main.swift
//  PingHelper
//
//  Created by Jacob Greenfield on 3/7/21.
//

import Foundation

class ServiceDelegate: NSObject, NSXPCListenerDelegate {
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        newConnection.exportedInterface = helperInterface
        newConnection.remoteObjectInterface = reverseInterface
        let helper = PingHelper(reverse: newConnection.remoteObjectProxy as! PingReverseProtocol)
        newConnection.exportedObject = helper
        newConnection.interruptionHandler = { [weak helper] in
            print("helper: connection interrupted")
            helper?.stopProcess()
        }
        newConnection.invalidationHandler = { [weak helper] in
            print("helper: connection invalidated")
            helper?.stopProcess()
        }
        newConnection.resume()
        return true
    }
}

let delegate = ServiceDelegate()
let listener = NSXPCListener.service()
listener.delegate = delegate
listener.resume()
