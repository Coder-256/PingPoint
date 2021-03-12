//
//  ViewController.swift
//  PingPoint
//
//  Created by Jacob Greenfield on 3/9/21.
//

import Cocoa
import Combine

class ViewController: NSViewController {
    @IBOutlet weak var leftButton: NSButton!
    @IBOutlet weak var rightButton: NSButton!
    @IBOutlet weak var label: NSTextField!

    var pingSubscription: AnyCancellable?
    var spaceObserver: NSObjectProtocol? = nil
    var window: NSPanel! { view.window as? NSPanel }
    var placeRight: Bool = true
    var isChild: Bool = false
    var childController: ViewController? = nil
    var activeButton: NSButton?
    var alert: NSAlert?

    @IBAction func leftButtonPressed(_ sender: Any) {
        buttonPressed()
    }

    @IBAction func rightButtonPressed(_ sender: Any) {
        buttonPressed()
    }

    func buttonPressed() {
        print("button pressed!")
        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = "Nuke"
        alert.informativeText = "Are you sure you want to nuke?"
        alert.addButton(withTitle: "Yes 💣")
        alert.addButton(withTitle: "Cancel")
        alert.beginSheetModal(for: window) { response in
            print("sheet response:", response)
            if response == .alertFirstButtonReturn {
                AppDelegate.shared.pingManager.helper.nuke()
            }
        }
    }

    func setText(_ string: String, color: NSColor? = nil) {
        var attributes: [NSAttributedString.Key: Any] = [
            .strokeColor: NSColor.textBackgroundColor,
            .strokeWidth: -3,
        ]
        if let color = color {
            attributes[.foregroundColor] = color
        }
        let attributed = NSAttributedString(string: string, attributes: attributes)
        label.attributedStringValue = attributed
        childController?.label.attributedStringValue = attributed
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

        if isChild {
            label.isHidden = true
            if placeRight {
                leftButton.isHidden = true
                activeButton = rightButton
            } else {
                rightButton.isHidden = true
                activeButton = leftButton
            }
        } else {
            window.ignoresMouseEvents = true
            leftButton.isHidden = true
            rightButton.isHidden = true

            if childController == nil {
                let childWindowController = NSStoryboard.main!.instantiateInitialController() as! NSWindowController
                childController = childWindowController.contentViewController as! Self
                childController!.isChild = true
                print("child controller loaded")
                window.addChildWindow(childController!.window!, ordered: .above)
            }

            setText("--")
            pingSubscription = AppDelegate.shared.pingSubject.sink { [unowned self] r in
                DispatchQueue.main.async {
                    if r.success {
                        let g = gradient(value: CGFloat(r.ping), low: 200, high: 1000)
                        let color = NSColor.labelColor.blended(withFraction: g, of: .red)
                        setText(String(format: "%.2f", r.ping), color: color)
                    } else {
                        setText("FAIL!", color: .red)
                    }
                }
            }

            spaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
                forName: NSWorkspace.activeSpaceDidChangeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.placeWindow()
            }
        }
    }

    override func viewWillDisappear() {
        NSWorkspace.shared.notificationCenter.removeObserver(spaceObserver as Any)
    }
}
