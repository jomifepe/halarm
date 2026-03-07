import Foundation

@Observable
final class SettingsViewModel {
    var baseURL: String = ""
    var token: String = ""
    var isTestingConnection = false
    var testResult: String?
    var testError: String?

    private var haService: HAService?
    private let settingsStore: SettingsStore

    init(settingsStore: SettingsStore) {
        self.settingsStore = settingsStore
        self.baseURL = settingsStore.baseURL
        self.token = settingsStore.token
    }

    func saveSettings() {
        settingsStore.baseURL = baseURL
        settingsStore.token = token
        haService = HAService(baseURL: baseURL, token: token)
    }

    func testConnection() async {
        let service = HAService(baseURL: baseURL, token: token)
        isTestingConnection = true
        defer { isTestingConnection = false }

        do {
            try await service.testConnection()
            testResult = "✓ Connection successful"
            testError = nil
            saveSettings()
        } catch {
            testError = error.localizedDescription
            testResult = nil
        }
    }

    func setupService(_ haService: HAService) {
        self.haService = haService
    }
}
