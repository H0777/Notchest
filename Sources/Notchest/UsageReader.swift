import Foundation

enum AIProvider: String, CaseIterable, Identifiable {
    case codex = "Codex", claude = "Claude Code"
    var id: String { rawValue }
    var defaultDirectory: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        if self == .codex {
            let codexHome = ProcessInfo.processInfo.environment["CODEX_HOME"].map { URL(fileURLWithPath: $0) } ?? home.appendingPathComponent(".codex")
            return codexHome.appendingPathComponent("sessions")
        }
        return home.appendingPathComponent(".claude/projects")
    }
}

struct TokenTally: Equatable {
    var input = 0
    var cached = 0
    var output = 0
    var total: Int { input + output }
    static func + (lhs: Self, rhs: Self) -> Self {
        TokenTally(input: lhs.input + rhs.input, cached: lhs.cached + rhs.cached, output: lhs.output + rhs.output)
    }
}

struct UsageWindow {
    let usedPercent: Double
    let minutes: Int
    let resetsAt: Date?
}

struct UsageSnapshot {
    var today = TokenTally()
    var week = TokenTally()
    var daily: [(date: Date, tokens: Int)] = []
    var primary: UsageWindow?
    var secondary: UsageWindow?
    var observedAt: Date?
    var scannedAt: Date?
    var fileCount = 0
    var eventCount = 0
    var missingDirectory = false
    var partial = false
    var unreadableFiles = 0
}

enum UsageReader {
    struct Entry {
        var date: Date
        var tally: TokenTally
        var key: String
    }
    private struct ParsedFile {
        var modified: Date
        var size: Int
        var weekStart: Date
        var entries: [String: Entry] = [:]
        var primary: UsageWindow?
        var secondary: UsageWindow?
        var observedAt: Date?
    }
    private static let cacheLock = NSLock()
    private static var cache: [String: ParsedFile] = [:]

    static func scan(provider: AIProvider, directory: URL, now: Date = Date()) -> UsageSnapshot {
        var snapshot = UsageSnapshot()
        snapshot.scannedAt = now
        let fm = FileManager.default
        guard fm.fileExists(atPath: directory.path) else { snapshot.missingDirectory = true; return snapshot }
        guard let enumerator = fm.enumerator(at: directory, includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey, .isRegularFileKey], options: [.skipsHiddenFiles], errorHandler: { _, _ in false }) else {
            snapshot.unreadableFiles = 1
            return snapshot
        }
        var files: [(URL, Date, Int)] = []
        for case let url as URL in enumerator {
            guard url.pathExtension == "jsonl", let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey, .isRegularFileKey]), values.isRegularFile == true else { continue }
            files.append((url, values.contentModificationDate ?? .distantPast, values.fileSize ?? 0))
        }
        files.sort { $0.1 > $1.1 }
        if files.count > 1500 { snapshot.partial = true }
        let calendar = Calendar.current
        let day = calendar.startOfDay(for: now)
        let weekStart = calendar.date(byAdding: .day, value: -6, to: day)!
        var entries: [String: Entry] = [:]
        var bytesRead = 0
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let fallbackFormatter = ISO8601DateFormatter()

        for (file, modified, size) in files.prefix(1500) {
            // Old unmodified transcripts cannot contribute to this seven-day view.
            if modified < weekStart { continue }
            guard size < 1024 * 1024 * 1024, bytesRead + size < 1024 * 1024 * 1024 else { snapshot.partial = true; continue }
            let key = provider.rawValue + file.path
            cacheLock.lock()
            let cached = cache[key]
            cacheLock.unlock()
            let parsed: ParsedFile
            if let cached, cached.modified == modified, cached.size == size, cached.weekStart <= weekStart {
                parsed = cached
            } else {
                guard let data = try? Data(contentsOf: file, options: .mappedIfSafe) else { snapshot.unreadableFiles += 1; continue }
                bytesRead += size
                parsed = parseFile(data, provider: provider, modified: modified, size: size, weekStart: weekStart, now: now, formatter: formatter, fallback: fallbackFormatter)
                cacheLock.lock()
                if cache.count > 2000 { cache.removeAll() }
                cache[key] = parsed
                cacheLock.unlock()
            }
            snapshot.fileCount += 1
            if let date = parsed.observedAt, snapshot.observedAt == nil || date > snapshot.observedAt! {
                snapshot.primary = parsed.primary; snapshot.secondary = parsed.secondary; snapshot.observedAt = date
            }
            for (key, entry) in parsed.entries where entry.date >= weekStart {
                if entries[key] == nil || entry.tally.total > entries[key]!.tally.total { entries[key] = entry }
            }
        }
        var daily: [Date: Int] = [:]
        for entry in entries.values {
            snapshot.week = snapshot.week + entry.tally
            let entryDay = calendar.startOfDay(for: entry.date)
            daily[entryDay, default: 0] += entry.tally.total
            if entryDay == day { snapshot.today = snapshot.today + entry.tally }
        }
        snapshot.eventCount = entries.count
        snapshot.daily = (0..<7).map { offset in
            let date = calendar.date(byAdding: .day, value: offset, to: weekStart)!
            return (date, daily[date] ?? 0)
        }
        return snapshot
    }

    private static func parseFile(_ data: Data, provider: AIProvider, modified: Date, size: Int, weekStart: Date, now: Date, formatter: ISO8601DateFormatter, fallback: ISO8601DateFormatter) -> ParsedFile {
        var parsed = ParsedFile(modified: modified, size: size, weekStart: weekStart)
        var previous = TokenTally()
        let marker = Data((provider == .codex ? "\"token_count\"" : "\"usage\"").utf8)
        for line in data.split(separator: 10) {
            guard line.range(of: marker) != nil,
                  let object = (try? JSONSerialization.jsonObject(with: Data(line))) as? [String: Any],
                  let timestamp = object["timestamp"] as? String,
                  let date = formatter.date(from: timestamp) ?? fallback.date(from: timestamp) else { continue }
            if provider == .codex {
                guard let payload = object["payload"] as? [String: Any], payload["type"] as? String == "token_count" else { continue }
                if let limits = payload["rate_limits"] as? [String: Any], parsed.observedAt == nil || date >= parsed.observedAt! {
                    parsed.primary = parseWindow(limits["primary"])
                    parsed.secondary = parseWindow(limits["secondary"])
                    parsed.observedAt = date
                }
                guard let info = payload["info"] as? [String: Any], let total = info["total_token_usage"] as? [String: Any] else { continue }
                let current = TokenTally(input: integer(total["input_tokens"]), cached: integer(total["cached_input_tokens"]), output: integer(total["output_tokens"]))
                let delta = TokenTally(input: max(0, current.input - previous.input), cached: max(0, current.cached - previous.cached), output: max(0, current.output - previous.output))
                previous = current
                if delta.total == 0 || date < weekStart || date > now.addingTimeInterval(60) { continue }
                let key = "\(timestamp):\(current.input):\(current.output)"
                parsed.entries[key] = Entry(date: date, tally: delta, key: key)
            } else {
                guard object["type"] as? String == "assistant", let message = object["message"] as? [String: Any], let usage = message["usage"] as? [String: Any], date >= weekStart, date <= now.addingTimeInterval(60) else { continue }
                let cached = integer(usage["cache_read_input_tokens"])
                let input = integer(usage["input_tokens"]) + cached + integer(usage["cache_creation_input_tokens"])
                let tally = TokenTally(input: input, cached: cached, output: integer(usage["output_tokens"]))
                let key = message["id"] as? String ?? "\(timestamp):\(input):\(tally.output)"
                if parsed.entries[key] == nil || tally.total > parsed.entries[key]!.tally.total { parsed.entries[key] = Entry(date: date, tally: tally, key: key) }
            }
        }
        return parsed
    }

    static func parseWindow(_ value: Any?) -> UsageWindow? {
        guard let dict = value as? [String: Any], let percent = (dict["used_percent"] as? NSNumber)?.doubleValue, percent.isFinite else { return nil }
        let reset = (dict["resets_at"] as? NSNumber).map { Date(timeIntervalSince1970: $0.doubleValue) }
        return UsageWindow(usedPercent: min(100, max(0, percent)), minutes: integer(dict["window_minutes"]), resetsAt: reset)
    }

    private static func integer(_ value: Any?) -> Int { max(0, (value as? NSNumber)?.intValue ?? 0) }
}
