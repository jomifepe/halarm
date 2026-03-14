import Foundation

@MainActor
@Observable
final class DevicePickerViewModel {
    var devices: [CoverEntity]
    var searchText: String = ""
    var isLoading = false
    var errorMessage: String?

    private var haService: HAService?
    private let cacheStore: AppCacheStore
    private let connectivityMonitor: ConnectivityMonitor
    private let settingsStore: SettingsStore

    var filteredDevices: [CoverEntity] {
        guard !searchText.isEmpty else { return devices }
        return devices.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.id.localizedCaseInsensitiveContains(searchText)
        }
    }

    init(
        cacheStore: AppCacheStore = .shared,
        connectivityMonitor: ConnectivityMonitor = .shared,
        settingsStore: SettingsStore = .shared
    ) {
        self.cacheStore = cacheStore
        self.connectivityMonitor = connectivityMonitor
        self.settingsStore = settingsStore
        self.devices = cacheStore.loadDevices(for: settingsStore.baseURL)
    }

    func setupService(_ haService: HAService) {
        self.haService = haService
        devices = cacheStore.loadDevices(for: settingsStore.baseURL)
    }

    func loadDevices() async {
        guard let haService else { return }

        if connectivityMonitor.isOffline {
            errorMessage = nil
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            devices = try await haService.fetchCoverEntities()
            cacheStore.saveDevices(devices, for: settingsStore.baseURL)
            connectivityMonitor.reportRequestSuccess()
            errorMessage = nil
        } catch {
            connectivityMonitor.reportRequestFailure(error)
            errorMessage = connectivityMonitor.isOffline
                ? nil
                : error.localizedDescription
        }
    }
}
