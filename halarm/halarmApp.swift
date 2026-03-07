import SwiftUI

@main
struct halarmApp: App {
    private let settingsStore = SettingsStore.shared
    @State private var haService: HAService?
    @State private var alarmListViewModel = AlarmListViewModel()

    var body: some Scene {
        WindowGroup {
            if settingsStore.isConfigured {
                AlarmListView(viewModel: alarmListViewModel, haService: haService)
                    .task {
                        if haService == nil {
                            let service = HAService(baseURL: settingsStore.baseURL, token: settingsStore.token)
                            haService = service
                            alarmListViewModel.setupService(haService: service)
                        }
                    }
            } else {
                SettingsView(viewModel: SettingsViewModel(settingsStore: settingsStore))
                    .onAppear {
                        if settingsStore.isConfigured {
                            let service = HAService(baseURL: settingsStore.baseURL, token: settingsStore.token)
                            haService = service
                            alarmListViewModel.setupService(haService: service)
                        }
                    }
            }
        }
    }
}
