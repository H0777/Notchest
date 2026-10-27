import Foundation
import Combine
import Security

struct StockQuote: Equatable {
    let symbol: String
    let price: Double
    let changePercent: String
    let tradingDate: String
    let fetchedAt: Date

    static func parse(_ data: Data, expectedSymbol: String, now: Date = Date()) throws -> StockQuote {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let quote = root["Global Quote"] as? [String: String],
              let symbol = quote["01. symbol"], symbol.caseInsensitiveCompare(expectedSymbol) == .orderedSame,
              let value = quote["05. price"], let price = Double(value), price.isFinite, price > 0,
              let date = quote["07. latest trading day"], !date.isEmpty else { throw StockError.noQuote }
        return StockQuote(symbol: symbol, price: price, changePercent: quote["10. change percent"] ?? "—", tradingDate: date, fetchedAt: now)
    }
}

enum StockError: LocalizedError {
    case missingKey, invalidKey, noQuote, requestFailed
    var errorDescription: String? {
        switch self {
        case .missingKey: return "Add an Alpha Vantage API key / أضف مفتاح Alpha Vantage"
        case .invalidKey: return "Keychain access failed / تعذّر الوصول إلى سلسلة المفاتيح"
        case .noQuote: return "No quote returned; check the symbol or API limit / لم يُرجع المزود سعرًا؛ تحقّق من الرمز أو حد الطلبات"
        case .requestFailed: return "Stock data request failed / تعذّر طلب بيانات السهم"
        }
    }
}

enum StockKeychain {
    private static var service: String { (Bundle.main.bundleIdentifier ?? "dev.notchest.island") + ".stocks" }
    private static var query: [String: Any] { [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: "alpha-vantage"] }

    static func save(_ key: String) throws {
        let data = Data(key.utf8)
        let status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var add = query; add[kSecValueData as String] = data
            guard SecItemAdd(add as CFDictionary, nil) == errSecSuccess else { throw StockError.invalidKey }
        } else if status != errSecSuccess { throw StockError.invalidKey }
    }
    static func load() throws -> String {
        var request = query
        request[kSecReturnData as String] = true
        request[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(request as CFDictionary, &result)
        guard status != errSecItemNotFound else { throw StockError.missingKey }
        guard status == errSecSuccess, let data = result as? Data, let value = String(data: data, encoding: .utf8), !value.isEmpty else { throw StockError.invalidKey }
        return value
    }
    static func delete() throws {
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw StockError.invalidKey }
    }
}

struct StockAlert: Codable {
    var threshold: Double
    var above: Bool
}

@MainActor
final class StocksModel: ObservableObject {
    @Published var symbols: [String]
    @Published var newSymbol = ""
    @Published var selected = ""
    @Published var keyInput = ""
    @Published var hasKey: Bool
    @Published var quotes: [String: StockQuote] = [:]
    @Published var loading = false
    @Published var error: String?
    @Published var alertInput = ""
    @Published var alertAbove = true
    @Published var alerts: [String: StockAlert]
    var onAlert: ((String, String) -> Void)?
    private var fired = Set<String>()
    private var task: Task<Void, Never>?
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let savedSymbols = defaults.stringArray(forKey: "stockSymbols") ?? []
        symbols = savedSymbols
        selected = savedSymbols.first ?? ""
        hasKey = defaults.bool(forKey: "stockHasKey")
        alerts = defaults.data(forKey: "stockAlerts").flatMap { try? JSONDecoder().decode([String: StockAlert].self, from: $0) } ?? [:]
    }

    func saveKey() {
        let key = keyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty, key.count <= 256 else { error = StockError.missingKey.localizedDescription; return }
        do { try StockKeychain.save(key); hasKey = true; defaults.set(true, forKey: "stockHasKey"); keyInput = ""; error = nil }
        catch { self.error = StockError.invalidKey.localizedDescription }
    }
    func removeKey() {
        do { try StockKeychain.delete(); hasKey = false; defaults.set(false, forKey: "stockHasKey"); quotes = [:]; error = nil }
        catch { self.error = StockError.invalidKey.localizedDescription }
    }
    func addSymbol() {
        let symbol = newSymbol.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.-")
        guard !symbol.isEmpty, symbol.count <= 16, symbol.unicodeScalars.allSatisfy({ allowed.contains($0) }) else { error = "Invalid ticker / رمز السهم غير صالح"; return }
        if !symbols.contains(symbol) {
            guard symbols.count < 20 else { error = "Watchlist is full / قائمة المتابعة ممتلئة"; return }
            symbols.append(symbol); defaults.set(symbols, forKey: "stockSymbols")
        }
        selected = symbol; newSymbol = ""; error = nil
    }
    func remove(_ symbol: String) {
        symbols.removeAll { $0 == symbol }; quotes.removeValue(forKey: symbol); alerts.removeValue(forKey: symbol)
        defaults.set(symbols, forKey: "stockSymbols"); saveAlerts(); if selected == symbol { selected = symbols.first ?? "" }
    }
    func setAlert() {
        guard !selected.isEmpty, let number = Double(alertInput), number.isFinite, number > 0 else { error = "Enter a positive price / أدخل سعرًا صحيحًا"; return }
        alerts[selected] = StockAlert(threshold: number, above: alertAbove); fired.remove(selected); saveAlerts(); error = nil
    }
    func removeAlert() { alerts.removeValue(forKey: selected); fired.remove(selected); saveAlerts() }
    private func saveAlerts() { if let data = try? JSONEncoder().encode(alerts) { defaults.set(data, forKey: "stockAlerts") } }

    func refresh() {
        let symbol = selected
        guard !symbol.isEmpty, !loading else { return }
        let key: String
        do { key = try StockKeychain.load() } catch { self.error = error.localizedDescription; return }
        var components = URLComponents(string: "https://www.alphavantage.co/query")!
        components.queryItems = [URLQueryItem(name: "function", value: "GLOBAL_QUOTE"), URLQueryItem(name: "symbol", value: symbol), URLQueryItem(name: "apikey", value: key)]
        guard let url = components.url else { error = StockError.requestFailed.localizedDescription; return }
        loading = true; error = nil; task?.cancel()
        task = Task { [weak self] in
            do {
                var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData); request.timeoutInterval = 20
                let session = URLSession(configuration: .ephemeral)
                defer { session.finishTasksAndInvalidate() }
                let (data, response) = try await session.data(for: request)
                guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode), data.count < 500_000 else { throw StockError.requestFailed }
                let quote = try StockQuote.parse(data, expectedSymbol: symbol)
                guard !Task.isCancelled, let self else { return }
                self.quotes[symbol] = quote; self.loading = false
                if let alert = self.alerts[symbol] {
                    let hit = alert.above ? quote.price >= alert.threshold : quote.price <= alert.threshold
                    if hit && !self.fired.contains(symbol) {
                        self.fired.insert(symbol)
                        self.onAlert?(symbol, "\(quote.price) · \(quote.tradingDate)")
                    } else if !hit { self.fired.remove(symbol) }
                }
            } catch {
                guard !Task.isCancelled else { return }
                self?.loading = false
                self?.error = (error as? StockError)?.localizedDescription ?? StockError.requestFailed.localizedDescription
            }
        }
    }
    func stop() { task?.cancel() }
}
