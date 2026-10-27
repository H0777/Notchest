// Used only in the isolated documentation capture build. Never copied into release Sources/.
import AppKit
import Foundation

@MainActor enum GalleryDemo {
    static func makeModel() -> AppModel {
        precondition(Bundle.main.bundleIdentifier == "dev.notchest.gallery", "Gallery requires its isolated bundle identifier")
        let defaults = UserDefaults.standard
        defaults.set(false, forKey: "arabic")
        defaults.set(true, forKey: "aiTracking")
        defaults.set(true, forKey: "clipboardEnabled")
        defaults.set("aurora", forKey: "accentTheme")
        return AppModel(startServices: false)
    }
    static func apply(_ app: AppModel) {
        app.expanded = true; app.pinned = true; app.hoverEnabled = false
        app.battery = nil; app.charging = false
        app.toast = "Documentation preview · illustrative data"
        app.sessions = 4
        app.note = "A little space to think.\n\nToday\n• Finish the landing page\n• Review the pull request\n• Make room for a focused hour\n\nIdeas\nKeep the useful things close. Let everything else wait."
        app.clips = [
            Clip(text: "Keep the useful things close.", source: "Sample note"),
            Clip(text: "https://github.com/H0777/Notchest", source: "Public project URL"),
            Clip(text: "swift build -c release", source: "Example command")
        ]
        let folder = URL(fileURLWithPath: "/tmp/Notchest-Demo")
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        for (name, content) in [("Project Notes.md", "# Example project\nDocumentation sample."), ("palette.json", "{\"accent\":\"aurora\"}"), ("Release Checklist.txt", "Build\nReview\nPublish")] {
            let url = folder.appendingPathComponent(name)
            try? content.write(to: url, atomically: true, encoding: .utf8)
            if let item = try? ShelfItem(url: url) { app.shelf.append(item) }
        }
        let dev = app.developer
        dev.workingDirectory = folder
        dev.workbenchInput = "{\"project\":\"Notchest\",\"platform\":\"macOS\",\"features\":[\"focus\",\"developer tools\",\"AI usage\"],\"localFirst\":true}"
        dev.transform("JSON")
        dev.regexPattern = "[A-Za-z]+"
        dev.snippets = [Snippet(name: "Release build", text: "swift build -c release"), Snippet(name: "Run project checks", text: "./check.sh"), Snippet(name: "Quick local server", text: "python3 -m http.server 8080")]
        dev.command = "printf 'Build completed successfully\\nAll checks passed\\n'"
        dev.gitOutput = "## main\n M README.md\n M site/index.html\n\n3 files changed, 42 insertions(+), 8 deletions(-)\n\nRecent commits\n8d24f1a  Add feature documentation\n70bd820  Refine island appearance\n43c8fa2  Initial example project"
        var usage = UsageSnapshot()
        usage.today = TokenTally(input: 142_800, cached: 101_200, output: 18_400)
        usage.week = TokenTally(input: 780_000, cached: 524_000, output: 96_000)
        let day = Calendar.current.startOfDay(for: Date())
        usage.daily = [64_000, 112_000, 98_000, 154_000, 131_000, 155_800, 161_200].enumerated().map { (Calendar.current.date(byAdding: .day, value: $0.offset - 6, to: day)!, $0.element) }
        usage.primary = UsageWindow(usedPercent: 28, minutes: 300, resetsAt: Date().addingTimeInterval(3_600))
        usage.secondary = UsageWindow(usedPercent: 42, minutes: 10_080, resetsAt: Date().addingTimeInterval(86_400 * 3))
        usage.fileCount = 7; usage.eventCount = 28; usage.observedAt = Date(); usage.scannedAt = Date()
        dev.usage = usage
        app.tools.cpuPercent = 12; app.tools.memoryPercent = 38; app.tools.freeDiskGB = 128
        app.tools.volume = 0.6
        app.tools.calculatorInput = "(12 + 8) * 3"; app.tools.calculatorResult = "60"
        app.tools.shortcutNames = ["Example: Start a focus session", "Example: Open workspace"]
        app.tools.selectedShortcut = app.tools.shortcutNames[0]
        app.tools.calendarLines = ["10:00 · Example design review", "14:30 · Example project planning"]
        app.tools.musicTitle = "Quiet Orbit"; app.tools.musicArtist = "Notchest demonstration track"
        app.tools.musicDuration = 214; app.tools.musicPosition = 78; app.tools.musicConnected = true
        app.tools.musicArtwork = NSImage(contentsOf: Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/Notchest.icns"))
        app.tools.showLyrics = true
        app.tools.lyrics = [LyricLine(id: 0, time: 0, text: "A little room to pause"), LyricLine(id: 1, time: 60, text: "A little time to breathe"), LyricLine(id: 2, time: 120, text: "Keep the useful things close")]
        app.weather.selected = WeatherCity(id: 1, name: "Lisbon", country: "Portugal", admin1: nil, latitude: 38.72, longitude: -9.14)
        app.weather.reading = WeatherResponse.Current(time: "2026-10-28T10:00", temperature_2m: 22, apparent_temperature: 23, weather_code: 0, wind_speed_10m: 8, is_day: 1)
        app.activity.record(id: "demo-build", title: "Example build finished", message: "All checks passed · sample task", state: "success", progress: 1, kind: "build")
        app.activity.record(id: "demo-files", title: "Example file ready", message: "Release Checklist.txt · sample event", kind: "download")
    }
}
