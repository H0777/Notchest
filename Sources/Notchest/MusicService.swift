import AppKit

struct MusicMetadata: Sendable {
    let title: String
    let artist: String
    let album: String
    let duration: Double
    let position: Double
    let playing: Bool
}

enum MusicService {
    static func read(_ player: String) -> (MusicMetadata?, String?) {
        guard player == "Music" || player == "Spotify" else { return (nil, nil) }
        let script = """
        if application "\(player)" is not running then return {}
        tell application "\(player)"
            if player state is stopped then return {}
            set t to current track
            return {name of t, artist of t, album of t, duration of t, player position, player state as text}
        end tell
        """
        var error: NSDictionary?
        guard let descriptor = NSAppleScript(source: script)?.executeAndReturnError(&error), error == nil else {
            return (nil, error?[NSAppleScript.errorMessage] as? String ?? "Music automation unavailable")
        }
        guard descriptor.numberOfItems >= 6 else { return (nil, nil) }
        let title = descriptor.atIndex(1)?.stringValue ?? ""
        let artist = descriptor.atIndex(2)?.stringValue ?? ""
        let album = descriptor.atIndex(3)?.stringValue ?? ""
        let rawDuration = descriptor.atIndex(4)?.doubleValue ?? 0
        let duration = player == "Spotify" ? rawDuration / 1000 : rawDuration
        let position = descriptor.atIndex(5)?.doubleValue ?? 0
        let playing = (descriptor.atIndex(6)?.stringValue ?? "").lowercased() == "playing"
        guard !title.isEmpty, duration.isFinite, position.isFinite else { return (nil, nil) }
        return (MusicMetadata(title: title, artist: artist, album: album, duration: max(0, duration), position: max(0, position), playing: playing), nil)
    }

    static func appleArtwork() -> Data? {
        var error: NSDictionary?
        let script = "tell application \"Music\" to get raw data of artwork 1 of current track"
        guard let descriptor = NSAppleScript(source: script)?.executeAndReturnError(&error), error == nil else { return nil }
        let data = descriptor.data
        return data.count <= 3_000_000 ? data : nil
    }

    static func spotifyArtworkURL() -> URL? {
        var error: NSDictionary?
        let script = "tell application \"Spotify\" to get artwork url of current track"
        guard let value = NSAppleScript(source: script)?.executeAndReturnError(&error).stringValue, error == nil,
              let url = URL(string: value), url.scheme == "https", let host = url.host?.lowercased(), host == "i.scdn.co" || host.hasSuffix(".scdn.co") else { return nil }
        return url
    }
}
