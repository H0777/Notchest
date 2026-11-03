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
    var lastEventAt: Date?
    var fileCount = 0
    var eventCount = 0
    var missingDirectory = false
    var partial = false
    var unreadableFiles = 0
    /// Disk bytes read this pass; unchanged files and appended tails stay cheap.
    var bytesRead = 0
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
        var identity: String
        var weekStart: Date
        var offset: UInt64 = 0
        var previous = TokenTally()
        var discardingOversizedLine = false
        var skippedOversizedLine = false
        var entries: [String: Entry] = [:]
        var primary: UsageWindow?
        var secondary: UsageWindow?
        var observedAt: Date?
        var lastEventAt: Date?
    }
    private static let cacheLock = NSLock()
    private static var cache: [String: ParsedFile] = [:]

    static func scan(provider: AIProvider, directory: URL, now: Date = Date()) -> UsageSnapshot {
        var snapshot = UsageSnapshot()
        snapshot.scannedAt = now
        let fm = FileManager.default
        guard fm.fileExists(atPath: directory.path) else { snapshot.missingDirectory = true; return snapshot }
        var enumerationErrors = 0
        guard let enumerator = fm.enumerator(at: directory, includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey, .isRegularFileKey], options: [.skipsHiddenFiles], errorHandler: { _, _ in enumerationErrors += 1; return true }) else {
            snapshot.unreadableFiles = 1
            return snapshot
        }
        var files: [(URL, Date, Int)] = []
        for case let url as URL in enumerator {
            if Task.isCancelled { return snapshot }
            guard url.pathExtension == "jsonl" else { continue }
            guard let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey, .isRegularFileKey]), values.isRegularFile == true else { snapshot.unreadableFiles += 1; continue }
            files.append((url, values.contentModificationDate ?? .distantPast, values.fileSize ?? 0))
        }
        snapshot.unreadableFiles += enumerationErrors
        files.sort { $0.1 > $1.1 }
        if files.count > 1500 { snapshot.partial = true }
        let calendar = Calendar.current
        let day = calendar.startOfDay(for: now)
        let weekStart = calendar.date(byAdding: .day, value: -6, to: day)!
        var entries: [String: Entry] = [:]
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let fallbackFormatter = ISO8601DateFormatter()

        for (file, modified, size) in files.prefix(1500) {
            if Task.isCancelled { return snapshot }
            // Old unmodified transcripts cannot contribute to this seven-day view.
            if modified < weekStart { continue }
            guard size < 1024 * 1024 * 1024 else { snapshot.partial = true; continue }
            let attributes = try? fm.attributesOfItem(atPath: file.path)
            let identity = "\(attributes?[.systemNumber] ?? 0):\(attributes?[.systemFileNumber] ?? 0)"
            let key = provider.rawValue + file.path
            cacheLock.lock()
            let cached = cache[key]
            cacheLock.unlock()
            let parsed: ParsedFile
            if let cached, cached.identity == identity, cached.modified == modified, cached.size == size, cached.weekStart == weekStart {
                parsed = cached
            } else {
                // JSONL writers append. Reuse only complete records from the same inode;
                // truncation, replacement, or a new day requires a fresh baseline.
                let base = cached.flatMap { $0.identity == identity && size > $0.size && $0.weekStart == weekStart ? $0 : nil }
                let offset = base?.offset ?? 0
                let needed = max(0, size - Int(offset))
                guard snapshot.bytesRead + needed < 1024 * 1024 * 1024 else { snapshot.partial = true; continue }
                do {
                    parsed = try readFile(file, provider: provider, base: base, modified: modified, size: size, identity: identity, weekStart: weekStart, now: now, formatter: formatter, fallback: fallbackFormatter)
                    snapshot.bytesRead += needed
                } catch {
                    snapshot.unreadableFiles += 1
                    // Keep the last good contribution during a transient read failure.
                    if let cached { merge(cached, into: &snapshot, entries: &entries, weekStart: weekStart, now: now) }
                    continue
                }
                cacheLock.lock()
                if cache.count > 2000 { cache.removeAll() }
                cache[key] = parsed
                cacheLock.unlock()
            }
            merge(parsed, into: &snapshot, entries: &entries, weekStart: weekStart, now: now)
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

    private static func merge(_ parsed: ParsedFile, into snapshot: inout UsageSnapshot, entries: inout [String: Entry], weekStart: Date, now: Date) {
        snapshot.fileCount += 1
        snapshot.partial = snapshot.partial || parsed.skippedOversizedLine
        if let date = parsed.observedAt, snapshot.observedAt == nil || date > snapshot.observedAt! {
            snapshot.primary = parsed.primary; snapshot.secondary = parsed.secondary; snapshot.observedAt = date
        }
        if let date = parsed.lastEventAt, snapshot.lastEventAt == nil || date > snapshot.lastEventAt! { snapshot.lastEventAt = date }
        for (key, entry) in parsed.entries where entry.date >= weekStart && entry.date <= now.addingTimeInterval(60) {
            if entries[key] == nil || entry.tally.total > entries[key]!.tally.total { entries[key] = entry }
        }
    }

    private static func readFile(_ url: URL, provider: AIProvider, base: ParsedFile?, modified: Date, size: Int, identity: String, weekStart: Date, now: Date, formatter: ISO8601DateFormatter, fallback: ISO8601DateFormatter) throws -> ParsedFile {
        var parsed = base ?? ParsedFile(modified: modified, size: size, identity: identity, weekStart: weekStart)
        parsed.modified = modified; parsed.size = size
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        try handle.seek(toOffset: parsed.offset)
        var remaining = size - Int(parsed.offset)
        var pending = Data()
        // Read bounded chunks, and cache only numeric entries, never transcript text.
        while remaining > 0 {
            try Task.checkCancellation()
            // Swift concurrency workers need an explicit pool for Foundation's
            // temporary NSData/JSON objects; otherwise a large first scan can
            // retain hundreds of MiB after the numeric result is published.
            try autoreleasepool {
                let chunk = try handle.read(upToCount: min(262_144, remaining)) ?? Data()
                guard !chunk.isEmpty else { throw CocoaError(.fileReadUnknown) }
                remaining -= chunk.count
                pending.append(chunk)
                while let newline = pending.firstIndex(of: 10) {
                    let consumed = pending.distance(from: pending.startIndex, to: newline) + 1
                    if !parsed.discardingOversizedLine, consumed <= 8 * 1024 * 1024 {
                        parseLine(Data(pending[..<newline]), provider: provider, parsed: &parsed, weekStart: weekStart, now: now, formatter: formatter, fallback: fallback)
                    } else { parsed.skippedOversizedLine = true }
                    parsed.discardingOversizedLine = false
                    parsed.offset += UInt64(consumed)
                    pending.removeSubrange(...newline)
                }
                if pending.count > 8 * 1024 * 1024 || parsed.discardingOversizedLine {
                    parsed.skippedOversizedLine = true
                    parsed.discardingOversizedLine = true
                    parsed.offset += UInt64(pending.count)
                    pending.removeAll(keepingCapacity: false)
                }
            }
        }
        // A valid final record does not need a trailing newline. An incomplete
        // one is left on disk and retried after the writer finishes it.
        if !pending.isEmpty, (try? JSONSerialization.jsonObject(with: pending)) != nil {
            parseLine(pending, provider: provider, parsed: &parsed, weekStart: weekStart, now: now, formatter: formatter, fallback: fallback)
            parsed.offset += UInt64(pending.count)
        }
        return parsed
    }

    private static func parseLine(_ line: Data, provider: AIProvider, parsed: inout ParsedFile, weekStart: Date, now: Date, formatter: ISO8601DateFormatter, fallback: ISO8601DateFormatter) {
        let marker = Data((provider == .codex ? "\"token_count\"" : "\"usage\"").utf8)
        guard line.range(of: marker) != nil,
              let object = (try? JSONSerialization.jsonObject(with: Data(line))) as? [String: Any],
              let timestamp = object["timestamp"] as? String,
              let date = formatter.date(from: timestamp) ?? fallback.date(from: timestamp) else { return }
        if provider == .codex {
            guard let payload = object["payload"] as? [String: Any], payload["type"] as? String == "token_count" else { return }
            if date <= now.addingTimeInterval(60), let limits = payload["rate_limits"] as? [String: Any], parseWindow(limits["primary"]) != nil || parseWindow(limits["secondary"]) != nil, parsed.observedAt == nil || date >= parsed.observedAt! {
                parsed.primary = parseWindow(limits["primary"])
                parsed.secondary = parseWindow(limits["secondary"])
                parsed.observedAt = date
            }
            guard let info = payload["info"] as? [String: Any], let total = info["total_token_usage"] as? [String: Any] else { return }
            let current = TokenTally(input: integer(total["input_tokens"]), cached: integer(total["cached_input_tokens"]), output: integer(total["output_tokens"]))
            let delta = TokenTally(input: max(0, current.input - parsed.previous.input), cached: max(0, current.cached - parsed.previous.cached), output: max(0, current.output - parsed.previous.output))
            parsed.previous = current
            if delta.total == 0 || date < weekStart || date > now.addingTimeInterval(60) { return }
            let key = "\(timestamp):\(current.input):\(current.output)"
            parsed.entries[key] = Entry(date: date, tally: delta, key: key)
        } else {
            guard object["type"] as? String == "assistant", let message = object["message"] as? [String: Any], let usage = message["usage"] as? [String: Any], date >= weekStart, date <= now.addingTimeInterval(60) else { return }
            let cached = integer(usage["cache_read_input_tokens"])
            let input = integer(usage["input_tokens"]) + cached + integer(usage["cache_creation_input_tokens"])
            let tally = TokenTally(input: input, cached: cached, output: integer(usage["output_tokens"]))
            let key = message["id"] as? String ?? "\(timestamp):\(input):\(tally.output)"
            if parsed.entries[key] == nil || tally.total > parsed.entries[key]!.tally.total { parsed.entries[key] = Entry(date: date, tally: tally, key: key) }
        }
        if parsed.lastEventAt == nil || date > parsed.lastEventAt! { parsed.lastEventAt = date }
    }

    static func parseWindow(_ value: Any?) -> UsageWindow? {
        guard let dict = value as? [String: Any], let percent = (dict["used_percent"] as? NSNumber)?.doubleValue, percent.isFinite else { return nil }
        let reset = (dict["resets_at"] as? NSNumber).map { Date(timeIntervalSince1970: $0.doubleValue) }
        return UsageWindow(usedPercent: min(100, max(0, percent)), minutes: integer(dict["window_minutes"]), resetsAt: reset)
    }

    private static func integer(_ value: Any?) -> Int { max(0, (value as? NSNumber)?.intValue ?? 0) }
}
