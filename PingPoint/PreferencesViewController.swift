//
//  PreferencesViewController.swift
//  PingPoint
//
//  Created by Jacob Greenfield on 3/27/21.
//

import Cocoa

class PreferencesViewController: NSViewController {
    @IBOutlet weak var bottomLeft: NSButton!
    @IBOutlet weak var bottomRight: NSButton!
    var floatRightObserver: DefaultsObserver?

    @IBAction func buttonPosition(_ sender: Any) {
        UserDefaults.standard.set(bottomRight.state == .on, forKey: "floatRight")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        floatRightObserver = DefaultsObserver(
            keyPath: "floatRight",
            options: [.initial, .new]
        ) { [weak self] change in
            guard let self = self else { return }
            if change![.newKey] as! Bool {
                self.bottomRight.state = .on
            } else {
                self.bottomLeft.state = .on
            }
        }
    }
}
