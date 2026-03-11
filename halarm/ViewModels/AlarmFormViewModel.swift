import Foundation

enum BlindDirection: String, CaseIterable {
    case open = "Open"
    case close = "Close"
}

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

    var isEditing: Bool { existingAlarm != nil }

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

        isLoading = true
        defer { isLoading = false }

        do {
            availableDevices = try await haService.fetchCoverEntities()
            errorMessage = nil

            // Pre-select the last used device if available
            if selectedDevice == nil, let lastDeviceId = SettingsStore.shared.lastDeviceId {
                selectedDevice = availableDevices.first(where: { $0.id == lastDeviceId })
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func saveAlarm() async throws {
        guard let haService, let device = selectedDevice else {
            throw NSError(domain: "AlarmForm", code: -1, userInfo: [NSLocalizedDescriptionKey: "Device not selected"])
        }

        // Save this device as the last used
        SettingsStore.shared.lastDeviceId = device.id
        SettingsStore.shared.lastDeviceName = device.name

        let baseLabel = label

        if createMultiple && existingAlarm == nil {
            for i in 0..<multipleCount {
                let totalMinutes = hour * 60 + minute + i * intervalMinutes
                let alarmHour = (totalMinutes / 60) % 24
                let alarmMinute = totalMinutes % 60
                let alarmLabel = "\(baseLabel) \(i + 1)"
                let alarmPosition: Int
                if blindDirection == .open {
                    alarmPosition = min(100, positionIncrement * (i + 1))
                } else {
                    alarmPosition = max(0, 100 - positionIncrement * (i + 1))
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
    }
}
