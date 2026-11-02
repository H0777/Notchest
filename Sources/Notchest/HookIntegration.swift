import Foundation
import Darwin

/// Writes token/config files atomically with owner-only permissions, including backups.
enum PrivateFile {
    static func write(_ data: Data, to url: URL) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let temporary = url.deletingLastPathComponent().appendingPathComponent(".notchest-\(UUID())")
        let fd = open(temporary.path, O_WRONLY | O_CREAT | O_EXCL, 0o600)
        guard fd >= 0 else { throw CocoaError(.fileWriteNoPermission) }
        let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
        defer { try? handle.close(); try? fm.removeItem(at: temporary) }
        try handle.write(contentsOf: data)
        guard fsync(fd) == 0, rename(temporary.path, url.path) == 0 else { throw CocoaError(.fileWriteUnknown) }
    }
}

enum AgentIntegration: String, CaseIterable, Identifiable {
    case codex, claude
    var id: String { rawValue }
    var title: String { self == .codex ? "Codex" : "Claude Code" }
    func configuration(home: URL = FileManager.default.homeDirectoryForCurrentUser, environment: [String: String] = ProcessInfo.processInfo.environment) -> URL {
        if self == .codex {
            return (environment["CODEX_HOME"].map { URL(fileURLWithPath: $0) } ?? home.appendingPathComponent(".codex")).appendingPathComponent("hooks.json")
        }
        return (environment["CLAUDE_CONFIG_DIR"].map { URL(fileURLWithPath: $0) } ?? home.appendingPathComponent(".claude")).appendingPathComponent("settings.json")
    }
}

enum HookInstaller {
    static var helper: URL? {
        let url = Bundle.main.executableURL?.deletingLastPathComponent().appendingPathComponent("NotchestCommand")
        return url.flatMap { FileManager.default.isExecutableFile(atPath: $0.path) ? $0 : nil }
    }
    static func shellQuote(_ text: String) -> String { "'" + text.replacingOccurrences(of: "'", with: "'\\''") + "'" }
    static func isOwned(_ item: [String: Any], provider: AgentIntegration) -> Bool {
        (item["hooks"] as? [[String: Any]] ?? []).contains {
            guard let command = $0["command"] as? String else { return false }
            return command.contains("NotchestCommand") && command.hasSuffix("--activity-hook " + provider.rawValue)
        }
    }
    @discardableResult static func install(_ provider: AgentIntegration, helper: URL, configuration: URL, remove: Bool = false) throws -> URL? {
        let fm = FileManager.default
        if let type = try? fm.attributesOfItem(atPath: configuration.path)[.type] as? FileAttributeType, type != .typeRegular { throw CocoaError(.fileReadInvalidFileName) }
        let original = fm.fileExists(atPath: configuration.path) ? try Data(contentsOf: configuration) : nil
        var root: [String: Any] = [:]
        if let original {
            guard original.count <= 2_000_000, let parsed = try JSONSerialization.jsonObject(with: original) as? [String: Any] else { throw CocoaError(.propertyListReadCorrupt) }
            root = parsed
        }
        if let value = root["hooks"], !(value is [String: Any]) { throw CocoaError(.propertyListReadCorrupt) }
        var hooks = root["hooks"] as? [String: Any] ?? [:]
        for event in Array(hooks.keys) {
            guard let entries = hooks[event] as? [[String: Any]] else { throw CocoaError(.propertyListReadCorrupt) }
            let kept = entries.filter { !isOwned($0, provider: provider) }
            if kept.isEmpty { hooks.removeValue(forKey: event) } else { hooks[event] = kept }
        }
        if !remove {
            let events = ["UserPromptSubmit", "PermissionRequest", "PreToolUse", "PostToolUse", "Stop", "SessionEnd"] + (provider == .codex ? ["Interrupt"] : ["Notification"])
            for event in events {
                var entry: [String: Any] = ["hooks": [["type": "command", "command": shellQuote(helper.path) + " --activity-hook " + provider.rawValue, "timeout": 2]]]
                if event == "Notification" { entry["matcher"] = "permission_prompt" }
                var entries = hooks[event] as? [[String: Any]] ?? []
                entries.append(entry); hooks[event] = entries
            }
        }
        root["hooks"] = hooks
        let data = try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys])
        guard data != original else { return nil }
        var backup: URL?
        if let original {
            let url = configuration.appendingPathExtension("notchest-backup-\(UUID().uuidString)")
            try PrivateFile.write(original, to: url); backup = url
        }
        try PrivateFile.write(data, to: configuration)
        return backup
    }
}
