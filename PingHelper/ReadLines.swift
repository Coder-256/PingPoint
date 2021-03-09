//
//  ReadLines.swift
//  PingHelper
//
//  Created by Jacob Greenfield on 3/8/21.
//

import Combine
import Foundation

/// Reads lines from the file handle into the given subject. This holds a weak reference to the subject, so you can
/// cancel the reader by simply deallocating the subject.
func readLines<S: Subject>(handle: FileHandle, subject: S) where S.Output == String?, S.Failure == Never {
    var buffer = Data()

    handle.readabilityHandler = { [weak subject] h in
        guard let subject = subject else { h.readabilityHandler = nil; return }
        let newData = h.availableData
        if newData.count == 0 {
            // We reached EOF
            h.readabilityHandler = nil
            if !buffer.isEmpty {
                subject.send(String(data: buffer, encoding: .utf8))
            }
            buffer.removeAll() // just in case
            subject.send(completion: .finished)
            return
        }
        var i = 0
        for j in 0..<newData.count {
            if newData[j] == 0x0A { // '\n'
                buffer.append(newData[i..<j])
                subject.send(String(data: buffer, encoding: .utf8))
                buffer.removeAll(keepingCapacity: true)
                i = j+1
            }
        }
        buffer.append(newData[i..<newData.count])
    }
}
