import SwiftUI

@main
@MainActor
struct halarmApp: App {
    @State private var settingsStore: SettingsStore
    @State private var alarmListViewModel: AlarmListViewModel
    @State private var haService: HAService

    init() {
        let settingsStore = SettingsStore.shared
        let alarmListViewModel = AlarmListViewModel()
        let haService = HAService(
            baseURL: settingsStore.baseURL,
            token: settingsStore.token
        )

        self._settingsStore = State(initialValue: settingsStore)
        self._alarmListViewModel = State(initialValue: alarmListViewModel)
        self._haService = State(initialValue: haService)
    }

    var body: some Scene {
        WindowGroup {
            if settingsStore.isConfigured {
                TabView {
                    Tab("Alarms", systemImage: "alarm") {
                        AlarmListView(viewModel: alarmListViewModel, haService: haService)
                    }
                    Tab("Settings", systemImage: "gearshape") {
                        SettingsView(viewModel: SettingsViewModel(settingsStore: settingsStore))
                    }
                }
            } else {
                SettingsView(
                    viewModel: SettingsViewModel(settingsStore: settingsStore),
                    isInitialSetup: true
                )
            }
        }
        .onChange(of: settingsStore.baseURL) { refreshService() }
        .onChange(of: settingsStore.token) { refreshService() }
    }

    private func refreshService() {
        let service = HAService(baseURL: settingsStore.baseURL, token: settingsStore.token)
        haService = service
        alarmListViewModel.setupService(haService: service)
    }
}
