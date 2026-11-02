import Foundation
import Darwin

// Hooks are observers. Always return empty JSON, including on failure, so they
// never approve, block, rewrite or continue an agent operation.
if CommandLine.arguments.count == 3, CommandLine.arguments[1] == "--activity-hook" {
    do {
        var input = Data()
        while input.count <= 1_048_576 {
            let chunk = try FileHandle.standardInput.read(upToCount: min(65_536, 1_048_577 - input.count)) ?? Data()
            if chunk.isEmpty { break }
            input.append(chunk)
        }
        guard input.count <= 1_048_576 else { print("{}"); exit(0) }
        let object = try JSONSerialization.jsonObject(with: input) as? [String: Any] ?? [:]
        if let payload = HookPayload.make(object, provider: CommandLine.arguments[2]) {
            let runtime = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/Notchest/Runtime/activity.json")
            let attributes = try FileManager.default.attributesOfItem(atPath: runtime.path)
            if attributes[.type] as? FileAttributeType == .typeRegular,
               (attributes[.ownerAccountID] as? NSNumber)?.uint32Value == getuid(),
               let mode = attributes[.posixPermissions] as? NSNumber, mode.intValue & 0o077 == 0,
               ((attributes[.size] as? NSNumber)?.intValue ?? 5000) <= 4096 {
                let descriptor = try JSONSerialization.jsonObject(with: Data(contentsOf: runtime)) as? [String: Any] ?? [:]
                if let token = descriptor["token"] as? String, !token.isEmpty, let port = descriptor["port"] as? Int, (1...65535).contains(port) {
                    var request = URLRequest(url: URL(string: "http://127.0.0.1:\(port)/v1/activity")!)
                    request.httpMethod = "POST"; request.timeoutInterval = 0.8
                    request.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.httpBody = try JSONSerialization.data(withJSONObject: payload)
                    let config = URLSessionConfiguration.ephemeral
                    config.httpShouldSetCookies = false
                    let session = URLSession(configuration: config)
                    let done = DispatchSemaphore(value: 0)
                    let task = session.dataTask(with: request) { _, _, _ in done.signal() }
                    task.resume(); _ = done.wait(timeout: .now() + 1)
                    session.invalidateAndCancel()
                }
            }
        }
    } catch { /* Optional observer: an unavailable app must not interrupt work. */ }
    print("{}")
    exit(0)
}

// Each explicit Run command gets its own process group, so Stop can interrupt
// the shell and its ordinary children without signalling the app's group.
guard CommandLine.arguments.count == 2 else { exit(64) }
if setsid() < 0 && getpgrp() != getpid() { perror("setsid"); exit(70) }
var arguments = [strdup("zsh"), strdup("-c"), strdup(CommandLine.arguments[1]), nil]
arguments.withUnsafeMutableBufferPointer { buffer in
    _ = execv("/bin/zsh", buffer.baseAddress!)
}
perror("execv")
exit(127)
