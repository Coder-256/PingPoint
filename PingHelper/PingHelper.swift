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
    var base = 0
    var nextBase = 0
    var process: Process? = nil
    var outputSink: AnyCancellable? = nil
    var errorSink: AnyCancellable? = nil
    var lastResult = Date()
    var timeout: TimeInterval = 10.0

    init(reverse: PingReverseProtocol) {
        self.reverse = reverse
    }

    func resetTimeout() {
        lastResult = Date()
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout + 0.1) { [weak self] in
            guard let self = self, let process = self.process else { return }
            if process.isRunning && Date().timeIntervalSince(self.lastResult) > self.timeout {
                print("timeout exceeded; will stop process")
                self.stopProcess()
            }
        }
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

    func update(base: Int, args: [String]) {
        self.base = base
        self.nextBase = base
        self.args = args
    }

    func resumePing() {
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
        process.terminationHandler = { [weak self] p in
            print("process exited: \(p.terminationReason == .exit ? "exit" : "signal"): \(p.terminationStatus)")
            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1)) {
                guard let self = self else { return }
                print("relaunch after process exit")
                self.base = self.nextBase
                self.resumePing()
            }
        }

        let outputSubject = PassthroughSubject<String?, Never>()
        outputSink = outputSubject.sink { [unowned self] line in
            guard let line = line else { print("STDOUT: DECODE FAILED"); return }
            print("line: \(line) --> ", terminator: "")
            let range = NSRange(location: 0, length: line.utf16.count)

            if
                let matched = responseRegex.firstMatch(in: line, range: range),
                let seq = Int((line as NSString).substring(with: matched.range(at: 1))),
                let pingMs = Double((line as NSString).substring(with: matched.range(at: 2)))
            {
                print("ping seq: \(seq), ms: \(pingMs)")
                resetTimeout()
                nextBase = max(nextBase, base + seq + 1)
                reverse.gotPing(number: base + seq, ping: pingMs, success: true)
            } else if
                let matched = timeoutRegex.firstMatch(in: line, range: range),
                let seq = Int((line as NSString).substring(with: matched.range(at: 1)))
            {
                print("timed out! seq: \(seq)")
                resetTimeout()
                nextBase = max(nextBase, base + seq + 1)
                reverse.gotPing(number: base + seq, ping: 0, success: false)
            } else {
                print("unknown")
            }
        }
        readLines(handle: stdout.fileHandleForReading, subject: outputSubject)

        let errorSubject = PassthroughSubject<String?, Never>()
        errorSink = errorSubject.sink { line in
            print("STDERR: \(line ?? "DECODE FAILED")")
        }
        readLines(handle: stderr.fileHandleForReading, subject: errorSubject)

        resetTimeout()

        // It seems like errors thrown here are for issues like an invalid executable, rather than
        // e.g. the exit status
        try! process.run()
    }

    /// Stops the ping process and cancels the keepAlive() call
    func cancelPing() {
        print("helper: will cancel ping")
        stopProcess()
        keepAliveCallback?()
        keepAliveCallback = nil
    }

    func stopProcess() {
        // `Process.interrupt()` sends SIGINT, `Process.terminate()` sends SIGTERM
        // Send SIGKILL instead
        if let pid = process?.processIdentifier { kill(pid, SIGKILL) }
        process = nil
        outputSink = nil
        errorSink = nil
    }

    func nuke(reply: @escaping (NSNumber) -> Void) {
        let nukePath = Bundle.main.path(forResource: "hsnuke", ofType: "sh")!
        print("nuke path: \(nukePath)")

        try! Process.run(URL(fileURLWithPath: "/bin/bash"), arguments: [nukePath]) { p in
            reply(NSNumber(value: p.terminationStatus))
        }
    }
}
