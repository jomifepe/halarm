import SwiftUI

@main
struct halarmApp: App {
    @State private var settingsStore = SettingsStore.shared
    @State private var haService: HAService?
    @State private var alarmListViewModel = AlarmListViewModel()
    @State private var refreshTrigger = false

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
        .onChange(of: settingsStore.baseURL) { _ in
            refreshTrigger.toggle()
        }
        .onChange(of: settingsStore.token) { _ in
            refreshTrigger.toggle()
        }
    }
}
