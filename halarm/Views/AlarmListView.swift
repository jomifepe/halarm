import SwiftUI

private enum ShiftDirection: String, CaseIterable {
    case forward = "Later"
    case backward = "Earlier"
}

struct AlarmListView: View {
    @State var viewModel: AlarmListViewModel
    @State private var showingNewAlarmForm = false
    @State private var showingSettings = false
    @State private var selectedAlarmForEdit: Alarm?
    @State private var showingTimeShift = false
    @State private var shiftHours: Int = 0
    @State private var shiftMinutes: Int = 0
    @State private var shiftDirection: ShiftDirection = .forward

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
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 8) {
                                    Text(alarm.timeString)
                                        .font(.headline)
                                    Text(alarm.weekdayString)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                Text(alarm.label)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
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

                    Button(action: { showingTimeShift = true }) {
                        Image(systemName: "clock.arrow.2.circlepath")
                    }
                    .disabled(viewModel.alarms.isEmpty)

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
            .sheet(isPresented: $showingTimeShift) {
                timeShiftSheet
            }
            .task {
                await viewModel.loadAlarms()
            }
        }
    }

    private var shiftSummary: String {
        let sign = shiftDirection == .forward ? "+" : "-"
        return "\(sign) \(shiftHours)h \(shiftMinutes)m"
    }

    @ViewBuilder
    private var timeShiftSheet: some View {
        NavigationStack {
            Form {
                Section("Direction") {
                    Picker("Direction", selection: $shiftDirection) {
                        ForEach(ShiftDirection.allCases, id: \.self) { dir in
                            Text(dir.rawValue).tag(dir)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Amount") {
                    Stepper("Hours: \(shiftHours)", value: $shiftHours, in: 0...23)
                    Stepper("Minutes: \(shiftMinutes)", value: $shiftMinutes, in: 0...59)
                }

                Section {
                    HStack {
                        Text("Shift")
                        Spacer()
                        Text(shiftSummary)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Shift Alarms")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingTimeShift = false
                        shiftHours = 0
                        shiftMinutes = 0
                        shiftDirection = .forward
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        let total = (shiftHours * 60 + shiftMinutes) * (shiftDirection == .forward ? 1 : -1)
                        showingTimeShift = false
                        shiftHours = 0
                        shiftMinutes = 0
                        shiftDirection = .forward
                        Task { await viewModel.shiftAlarms(byMinutes: total) }
                    }
                    .disabled(shiftHours == 0 && shiftMinutes == 0)
                }
            }
        }
    }
}
