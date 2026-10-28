import Foundation
import Darwin

struct CodexLiveSnapshot {
    let primary: UsageWindow?
    let secondary: UsageWindow?
    let lifetimeTokens: Int?
    let fetchedAt: Date
}

enum CodexLiveError: Error {
    case missing, failed, timeout, invalid

    func message(arabicUI: Bool) -> String { text.resolved(arabicUI: arabicUI) }

    var text: ServiceText {
        switch self {
        case .missing: return ServiceText("تعذّر العثور على Codex CLI", "Codex CLI not found")
        case .failed: return ServiceText("حساب Codex غير متاح", "Codex account is unavailable")
        case .timeout: return ServiceText("انتهت مهلة اتصال Codex", "Codex did not respond in time")
        case .invalid: return ServiceText("لم يُرجع Codex حدود الاستخدام", "Codex returned no usage limits")
        }
    }
}

enum CodexLiveReader {
    static func executable() -> URL? {
        let fromPath = (ProcessInfo.processInfo.environment["PATH"] ?? "").split(separator: ":").map { String($0) + "/codex" }
        let candidates = fromPath + [
            "/Applications/ChatGPT.app/Contents/Resources/codex-cli/CodexCLI.app/Contents/MacOS/codex",
            "/Applications/Codex.app/Contents/Resources/codex-cli/CodexCLI.app/Contents/MacOS/codex",
            "/opt/homebrew/bin/codex", "/usr/local/bin/codex"
        ]
        return candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }).map { URL(fileURLWithPath: $0) }
    }

    static func parse(rateResult: [String: Any], usageResult: [String: Any]?, now: Date = Date()) throws -> CodexLiveSnapshot {
        let buckets = rateResult["rateLimitsByLimitId"] as? [String: Any]
        let rate = (buckets?["codex"] as? [String: Any]) ?? (rateResult["rateLimits"] as? [String: Any])
        guard let rate else { throw CodexLiveError.invalid }
        func window(_ value: Any?) -> UsageWindow? {
            guard let entry = value as? [String: Any], let number = entry["usedPercent"] as? NSNumber, number.doubleValue.isFinite else { return nil }
            let minutes = max(0, (entry["windowDurationMins"] as? NSNumber)?.intValue ?? 0)
            let reset = (entry["resetsAt"] as? NSNumber).map { Date(timeIntervalSince1970: $0.doubleValue) }
            return UsageWindow(usedPercent: min(100, max(0, number.doubleValue)), minutes: minutes, resetsAt: reset)
        }
        let primary = window(rate["primary"]), secondary = window(rate["secondary"])
        guard primary != nil || secondary != nil else { throw CodexLiveError.invalid }
        let summary = usageResult?["summary"] as? [String: Any]
        let lifetime = (summary?["lifetimeTokens"] as? NSNumber)?.intValue
        return CodexLiveSnapshot(primary: primary, secondary: secondary, lifetimeTokens: lifetime, fetchedAt: now)
    }

    static func fetch() throws -> CodexLiveSnapshot {
        guard let executable = executable() else { throw CodexLiveError.missing }
        let process = Process()
        let input = Pipe(), output = Pipe()
        process.executableURL = executable
        process.arguments = ["app-server", "--listen", "stdio://"]
        process.standardInput = input; process.standardOutput = output; process.standardError = FileHandle.nullDevice
        do { try process.run() } catch { throw CodexLiveError.failed }
        defer {
            try? input.fileHandleForWriting.close()
            if process.isRunning { process.terminate() }
            try? output.fileHandleForReading.close()
        }
        let fd = output.fileHandleForReading.fileDescriptor
        var buffer = Data()
        let deadline = Date().addingTimeInterval(18)

        func send(_ value: [String: Any]) throws {
            let data = try JSONSerialization.data(withJSONObject: value) + Data([10])
            try input.fileHandleForWriting.write(contentsOf: data)
        }
        func readUntil(ids: Set<Int>) throws -> [Int: [String: Any]] {
            var results: [Int: [String: Any]] = [:]
            while !ids.isSubset(of: Set(results.keys)) {
                while let newline = buffer.firstIndex(of: 10) {
                    let line = Data(buffer[..<newline]); buffer.removeSubrange(...newline)
                    guard let item = (try? JSONSerialization.jsonObject(with: line)) as? [String: Any],
                          let id = item["id"] as? Int, ids.contains(id) else { continue }
                    if item["error"] != nil { results[id] = [:] }
                    else { results[id] = item["result"] as? [String: Any] ?? [:] }
                }
                if ids.isSubset(of: Set(results.keys)) { break }
                guard Date() < deadline else { throw CodexLiveError.timeout }
                var event = pollfd(fd: fd, events: Int16(POLLIN), revents: 0)
                let available = poll(&event, 1, 250)
                if available < 0 { throw CodexLiveError.failed }
                if available == 0 { continue }
                var chunk = [UInt8](repeating: 0, count: 8192)
                let count = Darwin.read(fd, &chunk, chunk.count)
                guard count > 0 else { throw CodexLiveError.failed }
                buffer.append(contentsOf: chunk.prefix(count))
                guard buffer.count <= 1_000_000 else { throw CodexLiveError.failed }
            }
            return results
        }
        try send(["id": 1, "method": "initialize", "params": ["clientInfo": ["name": "notchest", "title": "Notchest", "version": "0.3.0"]]])
        let initialized = try readUntil(ids: [1])
        guard initialized[1]?.isEmpty == false else { throw CodexLiveError.failed }
        try send(["method": "initialized", "params": [:]])
        try send(["id": 2, "method": "account/rateLimits/read"])
        let replies = try readUntil(ids: [2])
        guard let rate = replies[2], !rate.isEmpty else { throw CodexLiveError.failed }
        return try parse(rateResult: rate, usageResult: nil)
    }
}
