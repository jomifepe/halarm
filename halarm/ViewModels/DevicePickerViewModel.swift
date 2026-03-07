import Foundation

@Observable
final class DevicePickerViewModel {
    var devices: [CoverEntity] = []
    var searchText: String = ""
    var isLoading = false
    var errorMessage: String?

    private var haService: HAService?

    var filteredDevices: [CoverEntity] {
        guard !searchText.isEmpty else { return devices }
        return devices.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.id.localizedCaseInsensitiveContains(searchText)
        }
    }

    func setupService(_ haService: HAService) {
        self.haService = haService
    }

    func loadDevices() async {
        guard let haService else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            devices = try await haService.fetchCoverEntities()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
