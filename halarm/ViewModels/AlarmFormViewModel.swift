import Foundation

enum BlindDirection: String, CaseIterable {
    case open = "Open"
    case close = "Close"
}

@MainActor
@Observable
final class AlarmFormViewModel {
    var label: String = "Blinds Alarm"
    var hour: Int = 8
    var minute: Int = 0
    var weekdays: Set<Weekday> = []
    var selectedDevice: CoverEntity?
    var position: Int = 100

    var createMultiple: Bool = false
    var multipleCount: Int = 2
    var intervalMinutes: Int = 5
    var blindDirection: BlindDirection = .open
    var positionIncrement: Int = 10

    var availableDevices: [CoverEntity] = []
    var isLoading = false
    var errorMessage: String?

    private var haService: HAService?
    private var existingAlarm: Alarm?
    private let cacheStore: AppCacheStore
    private let connectivityMonitor: ConnectivityMonitor
    private let settingsStore: SettingsStore

    var isEditing: Bool { existingAlarm != nil }
    var isOffline: Bool { connectivityMonitor.isOffline }

    init(
        cacheStore: AppCacheStore = .shared,
        connectivityMonitor: ConnectivityMonitor = .shared,
        settingsStore: SettingsStore = .shared
    ) {
        self.cacheStore = cacheStore
        self.connectivityMonitor = connectivityMonitor
        self.settingsStore = settingsStore
        self.availableDevices = cacheStore.loadDevices(for: settingsStore.baseURL)

        if settingsStore.persistLastAlarmConfig {
            let store = settingsStore
            label = store.lastLabel
            hour = store.lastHour
            minute = store.lastMinute
            weekdays = Set(store.lastWeekdays.compactMap { Weekday(rawValue: $0) })
            position = store.lastPosition
            createMultiple = store.lastCreateMultiple
            multipleCount = store.lastMultipleCount
            intervalMinutes = store.lastIntervalMinutes
            blindDirection = BlindDirection(rawValue: store.lastBlindDirection) ?? .open
            positionIncrement = store.lastPositionIncrement
        }
    }

    var formattedTime: String {
        String(format: "%02d:%02d", hour, minute)
    }

    func setupService(_ haService: HAService) {
        self.haService = haService
    }

    func setupForEdit(_ alarm: Alarm) {
        existingAlarm = alarm
        label = alarm.label
        hour = alarm.hour
        minute = alarm.minute
        weekdays = alarm.weekdays
        selectedDevice = alarm.device
        position = alarm.position
    }

    func loadDevices() async {
        guard let haService else { return }

        if !availableDevices.isEmpty && selectedDevice == nil,
           let lastDeviceId = settingsStore.lastDeviceId {
            selectedDevice = availableDevices.first(where: { $0.id == lastDeviceId })
        }

        if connectivityMonitor.isOffline {
            errorMessage = nil
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            availableDevices = try await haService.fetchCoverEntities()
            cacheStore.saveDevices(availableDevices, for: settingsStore.baseURL)
            connectivityMonitor.reportRequestSuccess()
            errorMessage = nil

            // Pre-select the last used device if available
            if selectedDevice == nil, let lastDeviceId = settingsStore.lastDeviceId {
                selectedDevice = availableDevices.first(where: { $0.id == lastDeviceId })
            }
        } catch {
            connectivityMonitor.reportRequestFailure(error)
            errorMessage = connectivityMonitor.isOffline
                ? nil
                : error.localizedDescription
        }
    }

    func saveAlarm() async throws {
        guard !connectivityMonitor.isOffline else {
            throw NSError(
                domain: "AlarmForm",
                code: -2,
                userInfo: [NSLocalizedDescriptionKey: connectivityMonitor.statusMessage ?? "Home Assistant is unreachable."]
            )
        }

        guard let haService, let device = selectedDevice else {
            throw NSError(domain: "AlarmForm", code: -1, userInfo: [NSLocalizedDescriptionKey: "Device not selected"])
        }

        // Save this device as the last used
        settingsStore.lastDeviceId = device.id
        settingsStore.lastDeviceName = device.name

        // Persist alarm config if opted in
        if settingsStore.persistLastAlarmConfig && existingAlarm == nil {
            let store = settingsStore
            store.lastLabel = label
            store.lastHour = hour
            store.lastMinute = minute
            store.lastWeekdays = weekdays.map { $0.rawValue }
            store.lastPosition = position
            store.lastCreateMultiple = createMultiple
            store.lastMultipleCount = multipleCount
            store.lastIntervalMinutes = intervalMinutes
            store.lastBlindDirection = blindDirection.rawValue
            store.lastPositionIncrement = positionIncrement
        }

        let baseLabel = label

        if createMultiple && existingAlarm == nil {
            do {
                for i in 0..<multipleCount {
                    let totalMinutes = hour * 60 + minute + i * intervalMinutes
                    let alarmHour = (totalMinutes / 60) % 24
                    let alarmMinute = totalMinutes % 60
                    let alarmLabel = "\(baseLabel) \(i + 1)"
                    let positionOffset = positionIncrement * i
                    let alarmPosition: Int
                    if blindDirection == .open {
                        alarmPosition = min(100, position + positionOffset)
                    } else {
                        alarmPosition = max(0, position - positionOffset)
                    }
                    let alarm = Alarm(
                        id: UUID().uuidString,
                        label: alarmLabel,
                        hour: alarmHour,
                        minute: alarmMinute,
                        weekdays: weekdays,
                        isEnabled: true,
                        device: device,
                        position: alarmPosition
                    )
                    _ = try await haService.createAlarm(alarm)
                }
                connectivityMonitor.reportRequestSuccess()
            } catch {
                connectivityMonitor.reportRequestFailure(error)
                throw error
            }
            return
        }

        let alarm = Alarm(
            id: existingAlarm?.id ?? UUID().uuidString,
            label: baseLabel,
            hour: hour,
            minute: minute,
            weekdays: weekdays,
            isEnabled: true,
            device: device,
            position: min(100, max(0, position))
        )

        do {
            if let existing = existingAlarm {
                try await haService.updateAlarm(Alarm(
                    id: existing.id,
                    label: alarm.label,
                    hour: alarm.hour,
                    minute: alarm.minute,
                    weekdays: alarm.weekdays,
                    isEnabled: alarm.isEnabled,
                    device: alarm.device,
                    position: alarm.position
                ))
            } else {
                _ = try await haService.createAlarm(alarm)
            }

            connectivityMonitor.reportRequestSuccess()
        } catch {
            connectivityMonitor.reportRequestFailure(error)
            throw error
        }
    }
}
