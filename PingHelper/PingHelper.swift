//
//  PingHelper.swift
//  PingHelper
//
//  Created by Jacob Greenfield on 3/7/21.
//

import Combine
import Foundation
import System

let responseRegex = try! NSRegularExpression(pattern: #"icmp_seq=([0-9]+).*time=([0-9.]+) ms"#)
let timeoutRegex = try! NSRegularExpression(pattern: #"Request timeout for icmp_seq ([0-9]+)"#)

class PingHelper {
    var keepAliveCallback: (() -> Void)? = nil
    var reverse: PingReverseProtocol
    var args: [String]? = nil
    var newBase = 0
    var process: Process? = nil
    var outputSink: AnyCancellable? = nil
    var errorSink: AnyCancellable? = nil

    init(reverse: PingReverseProtocol) {
        self.reverse = reverse
    }

    deinit {
        print("deinit PingHelper")
        stopProcess()
    }
}

// MARK: - PingHelperProtocol
extension PingHelper: PingHelperProtocol {
    func keepAlive(canceled: @escaping () -> Void) {
        print("helper: will keep alive")
        keepAliveCallback?()
        keepAliveCallback = canceled
    }

    func resumePing(base: Int, args: [String]) {
        self.args = args
        self.newBase = base + 1
        stopProcess()
        print("start pinging")
        let pingURL = URL(fileURLWithPath: "/sbin/ping")
        let process = Process()
        self.process = process
        let stdout = Pipe()
        let stderr = Pipe()
        process.executableURL = pingURL
        process.arguments = args
        process.standardOutput = stdout
        process.standardError = stderr
        process.terminationHandler = { p in
            print("process exited: \(p.terminationReason == .exit ? "exit" : "signal"): \(p.terminationStatus)")
            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1)) { [weak self] in
                guard let self = self else { return }
                print("relaunch after process exit")
                self.resumePing(base: self.newBase, args: self.args!)
            }
        }
        // TODO: Handle crash and restart command (after short delay)
        let outputSubject = PassthroughSubject<String?, Never>()
        self.outputSink = outputSubject.sink { [unowned self] line in
            guard let line = line else { print("STDOUT: DECODE FAILED"); return }
            print("line: \(line) --> ", terminator: "")
            let range = NSRange(location: 0, length: line.utf16.count)

            if
                let matched = responseRegex.firstMatch(in: line, range: range),
                let seq = Int((line as NSString).substring(with: matched.range(at: 1))),
                let pingMs = Double((line as NSString).substring(with: matched.range(at: 2)))
            {
                print("ping seq: \(seq), ms: \(pingMs)")
                newBase = max(newBase, seq + 1)
                self.reverse.gotPing(number: base + seq, ping: pingMs, success: true)
            } else if
                let matched = timeoutRegex.firstMatch(in: line, range: range),
                let seq = Int((line as NSString).substring(with: matched.range(at: 1)))
            {
                print("timed out! seq: \(seq)")
                newBase = max(newBase, seq + 1)
                self.reverse.gotPing(number: base + seq, ping: 0, success: false)
            } else {
                print("unknown")
            }
        }
        readLines(handle: stdout.fileHandleForReading, subject: outputSubject)

        let errorSubject = PassthroughSubject<String?, Never>()
        self.errorSink = errorSubject.sink { line in
            print("STDERR: \(line ?? "DECODE FAILED")")
        }
        readLines(handle: stderr.fileHandleForReading, subject: errorSubject)
        
        process.launch()
    }

    /// Stops the ping process and cancels the keepAlive() call
    func cancelPing() {
        print("helper: will cancel ping")
        stopProcess()
        self.keepAliveCallback?()
        self.keepAliveCallback = nil
    }

    func stopProcess() {
        self.process?.interrupt()
        self.process = nil
        self.outputSink = nil
        self.errorSink = nil
    }

    func nuke() {
        let nukePath = Bundle.main.path(forResource: "hsnuke", ofType: "sh")!
        print("nuke path: \(nukePath)")
        let result = try? Process.run(URL(fileURLWithPath: "/bin/bash"), arguments: [nukePath], terminationHandler: nil)
        print(result as Any)
    }
}
