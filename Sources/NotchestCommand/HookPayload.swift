import Foundation

/// Only state, provider, session identity and the project name leave the input.
/// Prompt text, tool arguments, answers, transcript paths and credentials are ignored.
enum HookPayload {
    static func make(_ object: [String: Any], provider: String) -> [String: Any]? {
        guard ["codex", "claude"].contains(provider), let event = object["hook_event_name"] as? String else { return nil }
        let state: String
        switch event {
        case "UserPromptSubmit", "PreToolUse", "PostToolUse": state = "running"
        case "PermissionRequest": state = "waiting"
        case "Notification":
            guard object["notification_type"] as? String == "permission_prompt" else { return nil }
            state = "waiting"
        case "Stop": state = "success"
        case "SessionEnd", "Interrupt": state = "info"
        default: return nil
        }
        let source = provider == "codex" ? "Codex" : "Claude Code"
        let cwd = object["cwd"] as? String ?? ""
        let project = String(URL(fileURLWithPath: cwd.isEmpty ? "/" : cwd).lastPathComponent.prefix(100))
        let session = object["session_id"] as? String ?? cwd
        let hash = session.utf8.reduce(UInt64(14695981039346656037)) { ($0 ^ UInt64($1)) &* 1099511628211 }
        return ["id": "agent-\(provider)-\(String(hash, radix: 16))", "title": source, "source": source, "project": project, "state": state]
    }
}
