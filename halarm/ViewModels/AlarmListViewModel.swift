import Foundation

@Observable
final class AlarmListViewModel {
    var alarms: [Alarm] = []
    var isLoading = false
    var errorMessage: String?

    private var haService: HAService?

    func setupService(haService: HAService) {
        self.haService = haService
    }

    func loadAlarms() async {
        guard let haService else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            alarms = try await haService.fetchAlarms()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteAlarm(id: String) async {
        guard let haService else { return }

        // Remove optimistically first to keep SwiftUI animations consistent
        alarms.removeAll { $0.id == id }

        do {
            try await haService.deleteAlarm(id: id)
            errorMessage = nil
        } catch {
            await loadAlarms()  // restore on failure
            errorMessage = error.localizedDescription
        }
    }

    func shiftAlarms(byMinutes shiftMinutes: Int) async {
        guard let haService else { return }
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
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func toggleAlarm(id: String, enabled: Bool) async {
        guard let haService,
              let alarm = alarms.first(where: { $0.id == id }) else { return }

        do {
            try await haService.setEnabled(id: id, label: alarm.label, enabled: enabled)
            if let index = alarms.firstIndex(where: { $0.id == id }) {
                alarms[index].isEnabled = enabled
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
