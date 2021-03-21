//
//  DefaultsObserver.swift
//  PingPoint
//
//  Created by Jacob Greenfield on 3/20/21.
//

import Foundation

class DefaultsObserver: NSObject {
    var keyPath: String
    var block: ([NSKeyValueChangeKey: Any]?) -> ()

    init(keyPath: String, options: NSKeyValueObservingOptions = [], block: @escaping ([NSKeyValueChangeKey: Any]?) -> ()) {
        self.keyPath = keyPath
        self.block = block
        super.init()
        UserDefaults.standard.addObserver(self, forKeyPath: keyPath, options: options, context: nil)
    }

    override func observeValue(
        forKeyPath keyPath: String?,
        of object: Any?,
        change: [NSKeyValueChangeKey : Any]?,
        context: UnsafeMutableRawPointer?
    ) {
        block(change)
    }

    deinit {
        UserDefaults.standard.removeObserver(self, forKeyPath: keyPath)
    }
}
