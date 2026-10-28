import Foundation
import Combine

struct WeatherCity: Codable, Identifiable, Equatable {
    let id: Int
    let name: String
    let country: String?
    let admin1: String?
    let latitude: Double
    let longitude: Double
    var label: String { [name, admin1, country].compactMap { $0 }.joined(separator: ", ") }
}

struct WeatherSearchResponse: Decodable { let results: [WeatherCity]? }
struct WeatherResponse: Decodable {
    struct Current: Decodable {
        let time: String
        let temperature_2m: Double
        let apparent_temperature: Double
        let weather_code: Int
        let wind_speed_10m: Double
        let is_day: Int
    }
    let current: Current
    let timezone: String
}

@MainActor
final class WeatherModel: ObservableObject {
    @Published var query = ""
    @Published var candidates: [WeatherCity] = []
    @Published var selected: WeatherCity?
    @Published var reading: WeatherResponse.Current?
    @Published var loading = false
    @Published var error: String?
    /// Set from the app's language choice; weather wording resolves through it.
    var arabicUI = true
    private var refreshTimer: Timer?
    private var task: Task<Void, Never>?
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        selected = defaults.data(forKey: "weatherCity").flatMap { try? JSONDecoder().decode(WeatherCity.self, from: $0) }
    }

    func start() {
        if selected != nil { refresh() }
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 1800, repeats: true) { [weak self] _ in Task { @MainActor in self?.refresh() } }
    }
    func stop() { refreshTimer?.invalidate(); task?.cancel() }

    func search() {
        let name = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name.count <= 100 else { error = ServiceText("أدخل اسم المدينة", "Enter a city").resolved(arabicUI: arabicUI); return }
        task?.cancel()
        loading = true; error = nil; candidates = []
        var parts = URLComponents(string: "https://geocoding-api.open-meteo.com/v1/search")!
        parts.queryItems = [URLQueryItem(name: "name", value: name), URLQueryItem(name: "count", value: "8"), URLQueryItem(name: "language", value: "en"), URLQueryItem(name: "format", value: "json")]
        guard let url = parts.url else { loading = false; return }
        task = Task { [weak self] in
            do {
                let data = try await Self.fetch(url)
                let response = try JSONDecoder().decode(WeatherSearchResponse.self, from: data)
                guard !Task.isCancelled, let self else { return }
                self.candidates = (response.results ?? []).filter { (-90...90).contains($0.latitude) && (-180...180).contains($0.longitude) }
                self.loading = false
                if self.candidates.isEmpty { self.error = ServiceText("لم يُعثر على مدينة مطابقة", "No matching city").resolved(arabicUI: self.arabicUI) }
            } catch {
                guard !Task.isCancelled else { return }
                self?.error = ServiceText.network(error).resolved(arabicUI: self?.arabicUI ?? true); self?.loading = false
            }
        }
    }

    func choose(_ city: WeatherCity) {
        selected = city; candidates = []; reading = nil
        if let data = try? JSONEncoder().encode(city) { defaults.set(data, forKey: "weatherCity") }
        refresh()
    }

    func clearCity() {
        task?.cancel(); selected = nil; reading = nil; candidates = []; error = nil; loading = false
        defaults.removeObject(forKey: "weatherCity")
    }

    func refresh() {
        guard let city = selected else { return }
        task?.cancel(); loading = true; error = nil
        var parts = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        parts.queryItems = [URLQueryItem(name: "latitude", value: String(city.latitude)), URLQueryItem(name: "longitude", value: String(city.longitude)), URLQueryItem(name: "current", value: "temperature_2m,apparent_temperature,weather_code,wind_speed_10m,is_day"), URLQueryItem(name: "timezone", value: "auto")]
        guard let url = parts.url else { loading = false; return }
        task = Task { [weak self] in
            do {
                let data = try await Self.fetch(url)
                let response = try JSONDecoder().decode(WeatherResponse.self, from: data)
                guard !Task.isCancelled, let self, self.selected == city else { return }
                self.reading = response.current; self.loading = false
            } catch {
                guard !Task.isCancelled else { return }
                self?.error = ServiceText.network(error).resolved(arabicUI: self?.arabicUI ?? true); self?.loading = false
            }
        }
    }

    nonisolated private static func fetch(_ url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode), data.count <= 1_000_000 else { throw URLError(.badServerResponse) }
        return data
    }

    static func symbol(code: Int, isDay: Bool) -> String {
        switch code {
        case 0: return isDay ? "sun.max.fill" : "moon.stars.fill"
        case 1...3: return isDay ? "cloud.sun.fill" : "cloud.moon.fill"
        case 45, 48: return "cloud.fog.fill"
        case 51...67, 80...82: return "cloud.rain.fill"
        case 71...77, 85...86: return "cloud.snow.fill"
        case 95...99: return "cloud.bolt.rain.fill"
        default: return "cloud.fill"
        }
    }
}
