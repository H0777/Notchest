import AppKit
import Combine
import Network
import Security

struct NotchestActivity: Identifiable, Equatable {
    let id: String
    var title: String
    var message: String
    var state: String
    var progress: Double?
    var updated = Date()
    var url: URL?
    var kind: String = "message"
}

struct ActivityRequest: Decodable {
    var id: String?
    var title: String
    var message: String?
    var state: String?
    var progress: Double?
}

enum ActivityHTTP {
    enum Result { case incomplete, failure(Int), success(ActivityRequest) }
    static let maxHeader = 8_192
    static let maxBody = 16_384
    static let maxTotal = maxHeader + maxBody

    static func decode(_ data: Data, token: String) -> Result {
        guard data.count <= maxTotal else { return .failure(413) }
        let marker = Data("\r\n\r\n".utf8)
        guard let split = data.range(of: marker) else { return data.count > maxHeader ? .failure(431) : .incomplete }
        guard split.lowerBound <= maxHeader, let headerText = String(data: data[..<split.lowerBound], encoding: .utf8) else { return .failure(400) }
        let lines = headerText.components(separatedBy: "\r\n")
        guard let first = lines.first, first == "POST /v1/activity HTTP/1.1" || first == "POST /v1/activity HTTP/1.0" else { return .failure(404) }
        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            guard let colon = line.firstIndex(of: ":") else { return .failure(400) }
            let key = line[..<colon].trimmingCharacters(in: .whitespaces).lowercased()
            let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            guard !key.isEmpty, headers[key] == nil else { return .failure(400) }
            headers[key] = value
        }
        guard headers["transfer-encoding"] == nil else { return .failure(400) }
        guard let authorization = headers["authorization"], constantTimeEqual(authorization, "Bearer \(token)") else { return .failure(401) }
        guard headers["content-type"]?.lowercased().hasPrefix("application/json") == true,
              let lengthString = headers["content-length"], let length = Int(lengthString), length >= 1, length <= maxBody else { return .failure(400) }
        let bodyStart = split.upperBound
        guard data.count - bodyStart >= length else { return .incomplete }
        guard data.count - bodyStart == length,
              let request = try? JSONDecoder().decode(ActivityRequest.self, from: data[bodyStart..<(bodyStart + length)]),
              !request.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              request.title.count <= 100, (request.message?.count ?? 0) <= 500,
              (request.id?.count ?? 0) <= 80,
              ["running", "success", "failure", "info"].contains(request.state ?? "info"),
              request.progress.map({ $0.isFinite && (0...1).contains($0) }) ?? true else { return .failure(400) }
        return .success(request)
    }

    private static func constantTimeEqual(_ lhs: String, _ rhs: String) -> Bool {
        let left = Array(lhs.utf8), right = Array(rhs.utf8)
        guard left.count == right.count else { return false }
        return zip(left, right).reduce(UInt8(0)) { $0 | ($1.0 ^ $1.1) } == 0
    }
}

final class LocalActivityServer {
    private let queue = DispatchQueue(label: "dev.notchest.local-activity")
    private var listener: NWListener?
    private var connections: [ObjectIdentifier: NWConnection] = [:]
    let token: String
    let port: UInt16
    var onActivity: ((ActivityRequest) -> Void)?
    var onFailure: ((String) -> Void)?
    var onReady: (() -> Void)?

    init(token: String, port: UInt16 = 9999) { self.token = token; self.port = port }

    func start() throws {
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .hostPort(host: NWEndpoint.Host("127.0.0.1"), port: NWEndpoint.Port(rawValue: port)!)
        let listener = try NWListener(using: parameters)
        listener.stateUpdateHandler = { [weak self] state in
            if case .failed(let error) = state { self?.onFailure?(error.localizedDescription) }
            if case .ready = state { self?.onReady?() }
        }
        listener.newConnectionHandler = { [weak self] connection in self?.accept(connection) }
        self.listener = listener
        listener.start(queue: queue)
    }

    private func accept(_ connection: NWConnection) {
        guard connections.count < 16 else { connection.cancel(); return }
        let key = ObjectIdentifier(connection)
        connections[key] = connection
        connection.start(queue: queue)
        queue.asyncAfter(deadline: .now() + 5) { [weak self, weak connection] in
            guard let self, let connection, self.connections[key] != nil else { return }
            self.connections.removeValue(forKey: key)
            connection.cancel()
        }
        receive(connection, accumulated: Data())
    }

    private func receive(_ connection: NWConnection, accumulated: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { [weak self, weak connection] data, _, complete, error in
            guard let self, let connection else { return }
            var bytes = accumulated
            if let data { bytes.append(data) }
            switch ActivityHTTP.decode(bytes, token: self.token) {
            case .incomplete:
                if complete || error != nil { self.reply(connection, status: 400) }
                else { self.receive(connection, accumulated: bytes) }
            case .failure(let status): self.reply(connection, status: status)
            case .success(let request):
                self.onActivity?(request)
                self.reply(connection, status: 202)
            }
        }
    }

    private func reply(_ connection: NWConnection, status: Int) {
        let reason: String
        switch status { case 202: reason = "Accepted"; case 401: reason = "Unauthorized"; case 404: reason = "Not Found"; case 413: reason = "Payload Too Large"; case 431: reason = "Headers Too Large"; default: reason = "Bad Request" }
        let body = Data("{\"status\":\(status)}".utf8)
        let header = Data("HTTP/1.1 \(status) \(reason)\r\nContent-Type: application/json\r\nContent-Length: \(body.count)\r\nConnection: close\r\nCache-Control: no-store\r\n\r\n".utf8)
        connection.send(content: header + body, completion: .contentProcessed { [weak self, weak connection] _ in
            guard let self, let connection else { return }
            self.connections.removeValue(forKey: ObjectIdentifier(connection))
            connection.cancel()
        })
    }

    func stop() {
        listener?.cancel()
        listener = nil
        queue.async { [self] in
            self.connections.values.forEach { $0.cancel() }
            self.connections.removeAll()
        }
    }
}

@MainActor
final class ActivityCenter: ObservableObject {
    @Published var activities: [NotchestActivity] = []
    @Published var apiEnabled = false
    @Published var apiError: String?
    private var server: LocalActivityServer?
    private(set) var token = ""
    var onRecord: ((NotchestActivity) -> Void)?

    func startAPI() {
        guard server == nil else { return }
        var bytes = [UInt8](repeating: 0, count: 32)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else { apiError = "Could not generate a secure token"; return }
        token = Data(bytes).base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
        let server = LocalActivityServer(token: token)
        server.onActivity = { [weak self] request in Task { @MainActor in self?.accept(request) } }
        server.onFailure = { [weak self, weak server] error in
            Task { @MainActor in
                guard let self, self.server === server else { return }
                self.apiError = error
                self.stopAPI()
            }
        }
        do {
            try server.start()
            self.server = server
            apiError = nil
            apiEnabled = true
        } catch { apiError = error.localizedDescription; token = "" }
    }

    func stopAPI() {
        server?.stop()
        server = nil
        token = ""
        apiEnabled = false
    }

    func accept(_ request: ActivityRequest) {
        record(id: request.id ?? UUID().uuidString, title: request.title, message: request.message ?? "", state: request.state ?? "info", progress: request.progress)
    }

    func record(id: String = UUID().uuidString, title: String, message: String, state: String = "info", progress: Double? = nil, url: URL? = nil, kind: String = "message") {
        activities.removeAll { $0.id == id }
        let item = NotchestActivity(id: id, title: title, message: message, state: state, progress: progress, url: url, kind: kind)
        activities.insert(item, at: 0)
        activities = Array(activities.prefix(40))
        onRecord?(item)
    }

    func copyExample() {
        guard apiEnabled else { return }
        let command = "curl -s -X POST http://127.0.0.1:9999/v1/activity -H 'Authorization: Bearer \(token)' -H 'Content-Type: application/json' -d '{\"id\":\"build\",\"title\":\"Build\",\"message\":\"Started\",\"state\":\"running\",\"progress\":0.25}'"
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(command, forType: .string)
        pasteboard.setData(Data(), forType: NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType"))
    }
}
