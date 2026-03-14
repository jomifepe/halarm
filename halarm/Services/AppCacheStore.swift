import Foundation

@MainActor
final class AppCacheStore {
    static let shared = AppCacheStore()

    private let defaults = UserDefaults.standard
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private init() {}

    func loadAlarms(for baseURL: String) -> [Alarm] {
        load([Alarm].self, forKey: key(prefix: "halarm_cachedAlarms", baseURL: baseURL)) ?? []
    }

    func saveAlarms(_ alarms: [Alarm], for baseURL: String) {
        save(alarms, forKey: key(prefix: "halarm_cachedAlarms", baseURL: baseURL))
    }

    func loadDevices(for baseURL: String) -> [CoverEntity] {
        load([CoverEntity].self, forKey: key(prefix: "halarm_cachedDevices", baseURL: baseURL)) ?? []
    }

    func saveDevices(_ devices: [CoverEntity], for baseURL: String) {
        save(devices, forKey: key(prefix: "halarm_cachedDevices", baseURL: baseURL))
    }

    private func load<T: Decodable>(_ type: T.Type, forKey key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? decoder.decode(type, from: data)
    }

    private func save<T: Encodable>(_ value: T, forKey key: String) {
        guard let data = try? encoder.encode(value) else { return }
        defaults.set(data, forKey: key)
    }

    private func key(prefix: String, baseURL: String) -> String {
        let normalizedURL = baseURL
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        if normalizedURL.isEmpty {
            return "\(prefix)_default"
        }

        return "\(prefix)_\(normalizedURL)"
    }
}
