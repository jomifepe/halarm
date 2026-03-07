import Foundation

@Observable
final class AlarmFormViewModel {
    var label: String = ""
    var hour: Int = 7
    var minute: Int = 0
    var weekdays: Set<Weekday> = [.mon, .tue, .wed, .thu, .fri]
    var selectedDevice: CoverEntity?
    var position: Int = 100

    var availableDevices: [CoverEntity] = []
    var isLoading = false
    var errorMessage: String?

    private var haService: HAService?
    private var existingAlarm: Alarm?

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
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func saveAlarm() async throws {
        guard let haService, let device = selectedDevice else {
            throw NSError(domain: "AlarmForm", code: -1, userInfo: [NSLocalizedDescriptionKey: "Device not selected"])
        }

        let alarm = Alarm(
            id: existingAlarm?.id ?? UUID().uuidString,
            label: label.isEmpty ? "\(device.name) \(formattedTime)" : label,
            hour: hour,
            minute: minute,
            weekdays: weekdays,
            isEnabled: true,
            device: device,
            position: position
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
