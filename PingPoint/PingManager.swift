//
//  PingManager.swift
//  PingPoint
//
//  Created by Jacob Greenfield on 3/5/21.
//

import Foundation
import Combine

class PingManager {
    var args: [String]
    var callback: (PingResult) -> Void
    var connection: NSXPCConnection!
    var helper: PingHelperProtocol!
    var nextBase = 0
    var shouldRestart = true

    init(args: [String], callback: @escaping (PingResult) -> Void) {
        self.args = args
        self.callback = callback
        newConnection()
    }

    private func newConnection() {
        self.connection?.invalidate()
        self.connection = NSXPCConnection(serviceName: "me.jacobgreenfield.PingHelper")
        connection.exportedInterface = reverseInterface
        connection.exportedObject = ReverseResponder(parent: self)
        connection.remoteObjectInterface = helperInterface
        connection.interruptionHandler = { [weak self] in
            print("app: connection interrupted")
            self?.scheduleReconnect(invalidated: false)
        }
        connection.invalidationHandler = { [weak self] in
            print("app: connection invalidated")
            self?.scheduleReconnect(invalidated: true)
        }
        self.helper = (connection.remoteObjectProxy as! PingHelperProtocol)
        connection.resume()
    }

    private func scheduleReconnect(invalidated: Bool) {
        if invalidated {
            self.connection = nil
        }
        if shouldRestart {
            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1)) { [weak self] in
                guard let self = self else { return }
                if invalidated {
                    self.newConnection()
                }
                self.resume()
            }
        }
    }

    func resume() {
        shouldRestart = true
        if connection == nil {
            newConnection()
        }
        helper.keepAlive {
            print("app: keep alive cancelled callback")
        }
        helper.update(base: nextBase, args: args)
        helper.resumePing()
    }

    func suspend() {
        shouldRestart = false
        helper.cancelPing()
    }

    deinit {
        self.connection?.invalidate()
    }

    class ReverseResponder: PingReverseProtocol {
        weak var parent: PingManager?

        init(parent: PingManager) {
            self.parent = parent
        }

        func gotPing(number: Int, ping: Double, success: Bool) {
            guard let parent = parent else { return }
            let result = PingResult(number: number, ping: ping, success: success)
            parent.nextBase = result.number + 1
            parent.callback(result)
        }
    }
}

func leak<T: AnyObject>(_ value: T) {
    _ = Unmanaged.passRetained(value)
}
