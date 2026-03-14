import Foundation

@MainActor
@Observable
final class AlarmListViewModel {
    var alarms: [Alarm]
    var isLoading = false
    var errorMessage: String?

    private var haService: HAService?
    private let cacheStore: AppCacheStore
    private let connectivityMonitor: ConnectivityMonitor
    private let settingsStore: SettingsStore

    init(
        cacheStore: AppCacheStore = .shared,
        connectivityMonitor: ConnectivityMonitor = .shared,
        settingsStore: SettingsStore = .shared
    ) {
        self.cacheStore = cacheStore
        self.connectivityMonitor = connectivityMonitor
        self.settingsStore = settingsStore
        self.alarms = cacheStore.loadAlarms(for: settingsStore.baseURL)
    }

    func setupService(haService: HAService) {
        self.haService = haService
        alarms = cacheStore.loadAlarms(for: settingsStore.baseURL)
    }

    func loadAlarms() async {
        guard let haService else { return }

        if connectivityMonitor.isOffline {
            errorMessage = nil
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            alarms = try await haService.fetchAlarms()
            cacheStore.saveAlarms(alarms, for: settingsStore.baseURL)
            connectivityMonitor.reportRequestSuccess()
            errorMessage = nil
        } catch {
            connectivityMonitor.reportRequestFailure(error)
            errorMessage = connectivityMonitor.isOffline
                ? nil
                : error.localizedDescription
        }
    }

    func deleteAlarm(id: String) async {
        guard let haService else { return }
        guard !connectivityMonitor.isOffline else {
            errorMessage = connectivityMonitor.statusMessage ?? "Home Assistant is unreachable."
            return
        }

        // Remove optimistically first to keep SwiftUI animations consistent
        let previousAlarms = alarms
        alarms.removeAll { $0.id == id }

        do {
            try await haService.deleteAlarm(id: id)
            cacheStore.saveAlarms(alarms, for: settingsStore.baseURL)
            connectivityMonitor.reportRequestSuccess()
            errorMessage = nil
        } catch {
            connectivityMonitor.reportRequestFailure(error)
            alarms = previousAlarms
            errorMessage = error.localizedDescription
        }
    }

    func shiftAlarms(byMinutes shiftMinutes: Int) async {
        guard let haService else { return }
        guard !connectivityMonitor.isOffline else {
            errorMessage = connectivityMonitor.statusMessage ?? "Home Assistant is unreachable."
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            for alarm in alarms {
                let totalMinutes = alarm.hour * 60 + alarm.minute + shiftMinutes
                let wrapped = ((totalMinutes % 1440) + 1440) % 1440
                let shifted = Alarm(
                    id: alarm.id, label: alarm.label,
                    hour: wrapped / 60, minute: wrapped % 60,
                    weekdays: alarm.weekdays, isEnabled: alarm.isEnabled,
                    device: alarm.device, position: alarm.position
                )
                try await haService.updateAlarm(shifted)
            }
            alarms = try await haService.fetchAlarms()
            cacheStore.saveAlarms(alarms, for: settingsStore.baseURL)
            connectivityMonitor.reportRequestSuccess()
            errorMessage = nil
        } catch {
            connectivityMonitor.reportRequestFailure(error)
            errorMessage = error.localizedDescription
        }
    }

    func toggleAlarm(id: String, enabled: Bool) async {
        guard let haService,
              let alarm = alarms.first(where: { $0.id == id }) else { return }
        guard !connectivityMonitor.isOffline else {
            errorMessage = connectivityMonitor.statusMessage ?? "Home Assistant is unreachable."
            return
        }

        do {
            try await haService.setEnabled(id: id, label: alarm.label, enabled: enabled)
            if let index = alarms.firstIndex(where: { $0.id == id }) {
                alarms[index].isEnabled = enabled
            }
            cacheStore.saveAlarms(alarms, for: settingsStore.baseURL)
            connectivityMonitor.reportRequestSuccess()
            errorMessage = nil
        } catch {
            connectivityMonitor.reportRequestFailure(error)
            errorMessage = error.localizedDescription
        }
    }
}
