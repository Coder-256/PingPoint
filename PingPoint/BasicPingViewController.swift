//
//  BasicPingViewController.swift
//  PingPoint
//
//  Created by Jacob Greenfield on 3/9/21.
//

import Cocoa

class BasicPingViewController: NSViewController {
    @IBOutlet weak var label: NSTextField!
    var pingManager: PingManager!
    var spaceObserver: NSObjectProtocol? = nil
    var window: NSPanel! { view.window as? NSPanel }
    var placeRight: Bool = true

    func setText(_ string: String, color: NSColor? = nil) {
        var attributes: [NSAttributedString.Key: Any] = [
            .strokeColor: NSColor.textBackgroundColor,
            .strokeWidth: -3,
        ]
        if let color = color {
            attributes[.foregroundColor] = color
        }
        label.attributedStringValue = NSAttributedString(string: string, attributes: attributes)
    }

    func placeWindow() {
        let screenFrame = view.window!.screen!.frame
        if placeRight {
            window.setFrameOrigin(NSPoint(x: screenFrame.maxX - view.frame.width, y: screenFrame.minY))
        } else {
            window.setFrameOrigin(screenFrame.origin)
        }
    }

    override func viewDidLayout() {
        placeWindow()
    }

    func gradient(value: CGFloat, low: CGFloat, high: CGFloat) -> CGFloat {
        let ratio = (value - low)/(high - low)
        return min(1.0, max(0.0, ratio))
    }

    override func viewDidAppear() {
        super.viewDidAppear()

        window.isFloatingPanel = true
        window.isOpaque = false
        window.backgroundColor = .clear
        window.ignoresMouseEvents = true
        setText("--")
        pingManager = PingManager(args: ["1.1.1.1"]) { [unowned self] r in
            DispatchQueue.main.async {
                if r.success {
                    let g = gradient(value: CGFloat(r.ping), low: 500, high: 1500)
                    let color = NSColor.labelColor.blended(withFraction: g, of: .red)
                    setText(String(format: "%.2f", r.ping), color: color)
                } else {
                    setText("FAIL!", color: .red)
                }
            }
        }
        pingManager.resume()
        spaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.placeWindow()
        }
    }

    override func viewWillDisappear() {
        pingManager = nil
        NSWorkspace.shared.notificationCenter.removeObserver(spaceObserver as Any)
    }
}
