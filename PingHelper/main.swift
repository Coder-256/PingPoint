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
        newConnection.exportedObject = PingHelper(reverse: newConnection.remoteObjectProxy as! PingReverseProtocol)
        newConnection.interruptionHandler = {
            print("helper: connection interrupted")
        }
        newConnection.invalidationHandler = {
            print("helper: connection invalidated")
        }
        newConnection.resume()
        return true
    }
}

let delegate = ServiceDelegate()
let listener = NSXPCListener.service()
listener.delegate = delegate
listener.resume()
