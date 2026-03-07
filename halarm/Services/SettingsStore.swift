import Foundation

@Observable
final class SettingsStore {
    @ObservationIgnored
    private let defaults = UserDefaults.standard

    private static let baseURLKey = "halarm_baseURL"
    private static let tokenKey = "halarm_token"

    var baseURL: String {
        get { defaults.string(forKey: Self.baseURLKey) ?? "" }
        set { defaults.set(newValue, forKey: Self.baseURLKey) }
    }

    var token: String {
        get { defaults.string(forKey: Self.tokenKey) ?? "" }
        set { defaults.set(newValue, forKey: Self.tokenKey) }
    }

    var isConfigured: Bool {
        !baseURL.trimmingCharacters(in: .whitespaces).isEmpty &&
        !token.trimmingCharacters(in: .whitespaces).isEmpty
    }

    func clear() {
        baseURL = ""
        token = ""
    }

    static let shared = SettingsStore()
}
