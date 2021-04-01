//
//  ViewController.swift
//  PingPoint
//
//  Created by Jacob Greenfield on 3/9/21.
//

import Cocoa
import Combine

extension AXError: Error {}

class ViewController: NSViewController {
    static var lastPing = "--"

    @IBOutlet weak var leftButton: NSButton!
    @IBOutlet weak var rightButton: NSButton!
    @IBOutlet weak var label: NSTextField!

    var pingSubscription: AnyCancellable?
    var spaceObserver: NSObjectProtocol?
    var window: NSPanel! { view.window as? NSPanel }
    var placeRight: Bool = true
    var isChild: Bool = false
    var childController: ViewController?
    var activeButton: NSButton?
    var alert: NSAlert?
    var floatRightObserver: DefaultsObserver?

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

    func setText(_ string: String = ViewController.lastPing, color: NSColor = .black) {
        ViewController.lastPing = string
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
        if !isChild {
            print("place window")

            AppDelegate.shared.pingManager.isDockShown { [weak self] dockShown in
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    print("dock shown?: \(dockShown)")
                    let screenFrame: NSRect
                    if dockShown {
                        screenFrame = NSScreen.screens[0].visibleFrame
                    } else {
                        screenFrame = NSScreen.screens[0].frame
                    }

                    if self.placeRight {
                        self.window.setFrameOrigin(
                            NSPoint(x: screenFrame.maxX - self.view.frame.width, y: screenFrame.minY)
                        )
                    } else {
                        self.window.setFrameOrigin(screenFrame.origin)
                    }
                }
            }
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

        floatRightObserver = DefaultsObserver(
            keyPath: "floatRight",
            options: [.initial, .new]
        ) { [weak self] change in
            guard let self = self else { return }
            self.placeRight = change![.newKey] as! Bool
            if self.placeRight {
                self.leftButton.isHidden = true
                self.rightButton.isHidden = false
                self.activeButton = self.rightButton
            } else {
                self.rightButton.isHidden = true
                self.leftButton.isHidden = false
                self.activeButton = self.leftButton
            }
            self.placeWindow()
        }

        if isChild {
            window.setFrameOrigin(window.parent!.frame.origin)
            label.isHidden = true
        } else {
            setText()
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

            spaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
                forName: NSWorkspace.activeSpaceDidChangeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.placeWindow()
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
        }
    }

    override func viewWillDisappear() {
        NSWorkspace.shared.notificationCenter.removeObserver(spaceObserver as Any)
    }
}
