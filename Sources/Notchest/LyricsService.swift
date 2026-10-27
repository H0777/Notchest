import Foundation

struct LyricLine: Identifiable, Equatable {
    let id: Int
    let time: TimeInterval
    let text: String
}

enum LyricsParser {
    static func parse(_ source: String) -> [LyricLine] {
        guard let regex = try? NSRegularExpression(pattern: #"\[(\d{1,3}):(\d{2}(?:\.\d{1,3})?)\]"#) else { return [] }
        var rows: [(Double, String)] = []
        for line in source.components(separatedBy: .newlines) {
            let matches = regex.matches(in: line, range: NSRange(line.startIndex..., in: line))
            guard let last = matches.last, let end = Range(last.range, in: line)?.upperBound else { continue }
            let text = String(line[end...]).trimmingCharacters(in: .whitespacesAndNewlines)
            for match in matches {
                guard let minutesRange = Range(match.range(at: 1), in: line), let secondsRange = Range(match.range(at: 2), in: line),
                      let minutes = Double(line[minutesRange]), let seconds = Double(line[secondsRange]), seconds < 60 else { continue }
                rows.append((minutes * 60 + seconds, text))
            }
        }
        return rows.sorted { $0.0 < $1.0 }.enumerated().map { LyricLine(id: $0.offset, time: $0.element.0, text: $0.element.1) }
    }

    static func currentIndex(_ lines: [LyricLine], position: TimeInterval) -> Int? {
        lines.lastIndex(where: { $0.time <= position })
    }
}

struct LyricsRecord: Decodable {
    let trackName: String
    let artistName: String
    let syncedLyrics: String?
    let plainLyrics: String?
}

enum LyricsService {
    static func search(track: String, artist: String) async throws -> LyricsRecord? {
        var components = URLComponents(string: "https://lrclib.net/api/search")!
        components.queryItems = [URLQueryItem(name: "track_name", value: track), URLQueryItem(name: "artist_name", value: artist)]
        guard let url = components.url else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.setValue("NotchestMac/0.3 (local music player)", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode), data.count <= 1_000_000 else { throw URLError(.badServerResponse) }
        let records = try JSONDecoder().decode([LyricsRecord].self, from: data)
        return records.first { $0.trackName.caseInsensitiveCompare(track) == .orderedSame && $0.artistName.caseInsensitiveCompare(artist) == .orderedSame }
    }
}
