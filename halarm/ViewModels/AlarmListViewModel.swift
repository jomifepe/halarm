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

        do {
            try await haService.deleteAlarm(id: id)
            alarms.removeAll { $0.id == id }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func toggleAlarm(id: String, enabled: Bool) async {
        guard let haService else { return }

        do {
            try await haService.setEnabled(id: id, enabled: enabled)
            if let index = alarms.firstIndex(where: { $0.id == id }) {
                alarms[index].isEnabled = enabled
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
