//
//  AppDelegate.swift
//  PingPoint
//
//  Created by Jacob Greenfield on 3/9/21.
//

import Cocoa
import Combine

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    class var shared: AppDelegate { NSApplication.shared.delegate as! AppDelegate }
    var pingManager: PingManager!
    var pingSubject = PassthroughSubject<PingResult, Never>()

    override init() {
        UserDefaults.standard.register(defaults: [
            "showTitleBar": false,
            "bombRight": true,
        ])
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
        pingManager = PingManager(args: ["1.1.1.1"]) { [unowned self] in pingSubject.send($0) }
        pingManager.resume()
    }
}

