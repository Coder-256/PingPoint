//
//  Accessibility.swift
//  PingHelper
//
//  Created by Jacob Greenfield on 3/31/21.
//

import AppKit
import Foundation

extension AXError: Error {}

class UIElement {
    static var isTrusted: Bool {
        AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary)
    }

    static func getDock() -> UIElement {
        let dockPid = NSWorkspace.shared.runningApplications.first { $0.bundleIdentifier == "com.apple.dock" }!.processIdentifier
        return UIElement(inner: AXUIElementCreateApplication(dockPid))
    }

    let inner: AXUIElement

    init(inner: AXUIElement) {
        self.inner = inner
    }

    func checkError(_ error: AXError) throws {
        guard error == .success else { throw error }
    }

    func attributeNames() throws -> [String] {
        var names: CFArray?
        try checkError(AXUIElementCopyAttributeNames(inner, &names))
        return names as! [String]
    }

    func value(for attribute: String) throws -> CFTypeRef? {
        var result: CFTypeRef?
        try checkError(AXUIElementCopyAttributeValue(inner, attribute as CFString, &result))
        return result
    }

    func convertedValue<T>(for attribute: String, type: AXValueType, zeroed: T) throws -> T? {
        var result = zeroed
        let success = try withUnsafeMutablePointer(to: &result) {
            try AXValueGetValue(value(for: attribute) as! AXValue, type, UnsafeMutableRawPointer($0))
        }
        return success ? result : nil
    }

    func getChildren() throws -> [UIElement] {
        return (try value(for: kAXChildrenAttribute) as! [AXUIElement]).map(UIElement.init(inner:))
    }
}
