import Foundation

@Observable
final class SettingsStore {
    @ObservationIgnored
    private let defaults = UserDefaults.standard

    private static let baseURLKey = "halarm_baseURL"
    private static let tokenKeychainKey = "halarm_token"
    private static let lastDeviceIdKey = "halarm_lastDeviceId"
    private static let lastDeviceNameKey = "halarm_lastDeviceName"
    private static let persistLastConfigKey = "halarm_persistLastConfig"
    private static let lastLabelKey = "halarm_lastLabel"
    private static let lastHourKey = "halarm_lastHour"
    private static let lastMinuteKey = "halarm_lastMinute"
    private static let lastWeekdaysKey = "halarm_lastWeekdays"
    private static let lastPositionKey = "halarm_lastPosition"
    private static let lastCreateMultipleKey = "halarm_lastCreateMultiple"
    private static let lastMultipleCountKey = "halarm_lastMultipleCount"
    private static let lastIntervalMinutesKey = "halarm_lastIntervalMinutes"
    private static let lastBlindDirectionKey = "halarm_lastBlindDirection"
    private static let lastPositionIncrementKey = "halarm_lastPositionIncrement"

    var baseURL: String {
        didSet { defaults.set(baseURL, forKey: Self.baseURLKey) }
    }

    var token: String {
        didSet { KeychainHelper.save(token, forKey: Self.tokenKeychainKey) }
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

    var persistLastAlarmConfig: Bool {
        get { defaults.bool(forKey: Self.persistLastConfigKey) }
        set { defaults.set(newValue, forKey: Self.persistLastConfigKey) }
    }

    var lastLabel: String {
        get { defaults.string(forKey: Self.lastLabelKey) ?? "Blinds Alarm" }
        set { defaults.set(newValue, forKey: Self.lastLabelKey) }
    }

    var lastHour: Int {
        get { defaults.integer(forKey: Self.lastHourKey) }
        set { defaults.set(newValue, forKey: Self.lastHourKey) }
    }

    var lastMinute: Int {
        get { defaults.integer(forKey: Self.lastMinuteKey) }
        set { defaults.set(newValue, forKey: Self.lastMinuteKey) }
    }

    var lastWeekdays: [String] {
        get { defaults.stringArray(forKey: Self.lastWeekdaysKey) ?? [] }
        set { defaults.set(newValue, forKey: Self.lastWeekdaysKey) }
    }

    var lastPosition: Int {
        get { defaults.integer(forKey: Self.lastPositionKey) }
        set { defaults.set(newValue, forKey: Self.lastPositionKey) }
    }

    var lastCreateMultiple: Bool {
        get { defaults.bool(forKey: Self.lastCreateMultipleKey) }
        set { defaults.set(newValue, forKey: Self.lastCreateMultipleKey) }
    }

    var lastMultipleCount: Int {
        get { defaults.integer(forKey: Self.lastMultipleCountKey) }
        set { defaults.set(newValue, forKey: Self.lastMultipleCountKey) }
    }

    var lastIntervalMinutes: Int {
        get { defaults.integer(forKey: Self.lastIntervalMinutesKey) }
        set { defaults.set(newValue, forKey: Self.lastIntervalMinutesKey) }
    }

    var lastBlindDirection: String {
        get { defaults.string(forKey: Self.lastBlindDirectionKey) ?? "Open" }
        set { defaults.set(newValue, forKey: Self.lastBlindDirectionKey) }
    }

    var lastPositionIncrement: Int {
        get { defaults.integer(forKey: Self.lastPositionIncrementKey) }
        set { defaults.set(newValue, forKey: Self.lastPositionIncrementKey) }
    }

    var isConfigured: Bool {
        !baseURL.trimmingCharacters(in: .whitespaces).isEmpty &&
        !token.trimmingCharacters(in: .whitespaces).isEmpty
    }

    func clear() {
        baseURL = ""
        token = ""
    }

    private init() {
        self.baseURL = defaults.string(forKey: Self.baseURLKey) ?? "http://homeassistant.local:8123"
        self.token = KeychainHelper.load(forKey: Self.tokenKeychainKey) ?? ""
        defaults.register(defaults: [
            Self.lastLabelKey: "Blinds Alarm",
            Self.lastHourKey: 8,
            Self.lastMinuteKey: 0,
            Self.lastPositionKey: 100,
            Self.lastMultipleCountKey: 2,
            Self.lastIntervalMinutesKey: 5,
            Self.lastBlindDirectionKey: "Open",
            Self.lastPositionIncrementKey: 10
        ])
    }

    static let shared = SettingsStore()
}
