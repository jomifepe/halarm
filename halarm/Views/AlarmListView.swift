import SwiftUI

struct AlarmListView: View {
    @State var viewModel: AlarmListViewModel
    @State private var showingNewAlarmForm = false
    @State private var showingSettings = false
    @State private var selectedAlarmForEdit: Alarm?

    private let haService: HAService?

    init(viewModel: AlarmListViewModel = AlarmListViewModel(), haService: HAService? = nil) {
        self._viewModel = State(initialValue: viewModel)
        self.haService = haService
    }

    var body: some View {
        NavigationStack {
            List {
                if viewModel.isLoading && viewModel.alarms.isEmpty {
                    ProgressView()
                } else if let error = viewModel.errorMessage {
                    Text("Error: \(error)")
                        .foregroundColor(.red)
                } else if viewModel.alarms.isEmpty {
                    Text("No alarms yet")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(viewModel.alarms) { alarm in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(alarm.label)
                                    .font(.headline)
                                HStack(spacing: 8) {
                                    Text(alarm.timeString)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    Text(alarm.weekdayString)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }

                            Spacer()

                            Toggle("", isOn: Binding(
                                get: { alarm.isEnabled },
                                set: { newValue in
                                    Task { await viewModel.toggleAlarm(id: alarm.id, enabled: newValue) }
                                }
                            ))
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedAlarmForEdit = alarm
                        }
                    }
                    .onDelete { indexSet in
                        let alarmsToDelete = indexSet.map { viewModel.alarms[$0] }
                        Task {
                            for alarm in alarmsToDelete {
                                await viewModel.deleteAlarm(id: alarm.id)
                            }
                        }
                    }
                }
            }
            .refreshable {
                await viewModel.loadAlarms()
            }
            .navigationTitle("Alarms")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button(action: { showingNewAlarmForm = true }) {
                        Image(systemName: "plus")
                    }

                    Button("Settings", systemImage: "ellipsis") {
                        showingSettings = true
                    }
                }
            }
            .sheet(isPresented: $showingNewAlarmForm) {
                let formVM = AlarmFormViewModel()
                AlarmFormView(viewModel: formVM, haService: haService)
                    .onDisappear {
                        Task {
                            await viewModel.loadAlarms()
                        }
                    }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView(viewModel: SettingsViewModel(settingsStore: SettingsStore.shared))
            }
            .sheet(item: $selectedAlarmForEdit) { alarm in
                let formVM = AlarmFormViewModel()
                return AlarmFormView(viewModel: formVM, haService: haService)
                    .onAppear {
                        formVM.setupForEdit(alarm)
                    }
                    .onDisappear {
                        Task {
                            await viewModel.loadAlarms()
                        }
                    }
            }
            .task {
                await viewModel.loadAlarms()
            }
        }
    }
}
