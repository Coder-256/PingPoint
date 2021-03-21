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
    var window: NSPanel! { view.window as? NSPanel }
    var placeRight: Bool = true
    var isChild: Bool = false
    var childController: ViewController?
    var activeButton: NSButton?
    var alert: NSAlert?
    var showTitleBarObserver: DefaultsObserver?
    var bombOnRightObserver: DefaultsObserver?

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
                AppDelegate.shared.pingManager.helper.nuke { status in
                    if status == 0 {
                        print("nuke successful")
                    } else {
                        print("nuke failed: \(status.int32Value)")
                    }
                }
            }
        }
    }

    func setText(_ string: String, color: NSColor = .black) {
        let attributes: [NSAttributedString.Key: Any] = [
            .strokeColor: NSColor.white,
            .strokeWidth: -3,
            .foregroundColor: color,
        ]
        let attributed = NSAttributedString(string: string, attributes: attributes)
        label.attributedStringValue = attributed
        childController?.label.attributedStringValue = attributed
    }

    func placeWindow() {
        let screenFrame = view.window!.screen!.frame
        if placeRight {
            window.setFrameOrigin(
                NSPoint(x: screenFrame.maxX - view.frame.width, y: screenFrame.minY)
            )
        } else {
            window.setFrameOrigin(screenFrame.origin)
        }
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
            window.setFrameOrigin(window.parent!.frame.origin)
            label.isHidden = true
            if placeRight {
                leftButton.isHidden = true
                activeButton = rightButton
            } else {
                rightButton.isHidden = true
                activeButton = leftButton
            }

            bombOnRightObserver = DefaultsObserver(
                keyPath: "bombRight",
                options: [.initial, .new]
            ) { [weak self] change in
                guard let self = self else { return }
                let bombOnRight = change![.newKey] as! Bool
                self.placeRight = bombOnRight
                if self.placeRight {
                    self.leftButton.isHidden = true
                    self.rightButton.isHidden = false
                    self.activeButton = self.rightButton
                } else {
                    self.rightButton.isHidden = true
                    self.leftButton.isHidden = false
                    self.activeButton = self.leftButton
                }
            }
        } else {
            setText("--")
            window.windowController!.shouldCascadeWindows = false
            window.windowController!.windowFrameAutosaveName = "mainWindow"
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

            pingSubscription = AppDelegate.shared.pingSubject.sink { [weak self] r in
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    if r.success {
                        let g = self.gradient(value: CGFloat(r.ping), low: 200, high: 1000)
                        let color = NSColor.black.blended(withFraction: g, of: .red)!
                        self.setText(String(format: "%.2f", r.ping), color: color)
                    } else {
                        self.setText("FAIL!", color: .red)
                    }
                }
            }

            showTitleBarObserver = DefaultsObserver(
                keyPath: "showTitleBar",
                options: [.initial, .new]
            ) { [weak self] change in
                guard let self = self else { return }
                let showTitleBar = change![.newKey] as! Bool
                if showTitleBar {
                    self.window.styleMask.insert(.titled)
                    self.window.ignoresMouseEvents = false
                } else {
                    self.window.styleMask.remove(.titled)
                    self.window.ignoresMouseEvents = true
                }

            }
        }
    }
}
