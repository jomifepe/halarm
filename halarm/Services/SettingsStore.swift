import Foundation

@Observable
final class SettingsStore {
    @ObservationIgnored
    private let defaults = UserDefaults.standard

    private static let baseURLKey = "halarm_baseURL"
    private static let tokenKey = "halarm_token"
    private static let lastDeviceIdKey = "halarm_lastDeviceId"
    private static let lastDeviceNameKey = "halarm_lastDeviceName"

    var baseURL: String {
        get { defaults.string(forKey: Self.baseURLKey) ?? "" }
        set { defaults.set(newValue, forKey: Self.baseURLKey) }
    }

    var token: String {
        get { defaults.string(forKey: Self.tokenKey) ?? "" }
        set { defaults.set(newValue, forKey: Self.tokenKey) }
    }

    var lastDeviceId: String? {
        get { defaults.string(forKey: Self.lastDeviceIdKey) }
        set {
            if let newValue {
                defaults.set(newValue, forKey: Self.lastDeviceIdKey)
            } else {
                defaults.removeObject(forKey: Self.lastDeviceIdKey)
            }
        }
    }

    var lastDeviceName: String? {
        get { defaults.string(forKey: Self.lastDeviceNameKey) }
        set {
            if let newValue {
                defaults.set(newValue, forKey: Self.lastDeviceNameKey)
            } else {
                defaults.removeObject(forKey: Self.lastDeviceNameKey)
            }
        }
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
