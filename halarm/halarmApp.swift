import SwiftUI

@main
struct halarmApp: App {
    @State private var settingsStore = SettingsStore.shared
    @State private var alarmListViewModel = AlarmListViewModel()
    @State private var haService = HAService(
        baseURL: SettingsStore.shared.baseURL,
        token: SettingsStore.shared.token
    )

    var body: some Scene {
        WindowGroup {
            if settingsStore.isConfigured {
                TabView {
                    Tab("Alarms", systemImage: "alarm") {
                        AlarmListView(viewModel: alarmListViewModel, haService: haService)
                            .task {
                                alarmListViewModel.setupService(haService: haService)
                            }
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
