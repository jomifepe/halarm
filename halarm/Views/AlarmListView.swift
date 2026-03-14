import SwiftUI

private enum ShiftDirection: String, CaseIterable {
    case backward = "Earlier"
    case forward = "Later"
}

@MainActor
struct AlarmListView: View {
    @State var viewModel: AlarmListViewModel
    @State private var connectivityMonitor: ConnectivityMonitor
    @State private var showingNewAlarmForm = false
    @State private var selectedAlarmForEdit: Alarm?
    @State private var showingTimeShift = false
    @State private var shiftDate: Date = Calendar.current.date(byAdding: .minute, value: 2, to: Calendar.current.startOfDay(for: Date())) ?? Calendar.current.startOfDay(for: Date())
    @State private var shiftDirection: ShiftDirection = .forward

    private let haService: HAService?

    init(viewModel: AlarmListViewModel, haService: HAService? = nil) {
        self._viewModel = State(initialValue: viewModel)
        self._connectivityMonitor = State(initialValue: ConnectivityMonitor.shared)
        self.haService = haService
    }

    var body: some View {
        NavigationStack {
            List {
                if let message = connectivityMonitor.statusMessage {
                    Label(message, systemImage: "wifi.exclamationmark")
                        .font(.subheadline)
                        .foregroundColor(.orange)
                }

                if let error = viewModel.errorMessage,
                   !viewModel.alarms.isEmpty,
                   error != connectivityMonitor.statusMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.secondary)
                    }
                }

                if viewModel.isLoading && viewModel.alarms.isEmpty {
                    ProgressView()
                } else if let error = viewModel.errorMessage,
                          viewModel.alarms.isEmpty,
                          error != connectivityMonitor.statusMessage {
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
                                        .font(.title)
                                        .fontWeight(.semibold)
                                    if !alarm.weekdayString.isEmpty {
                                        Text(alarm.weekdayString)
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                Text("\(alarm.label) · \(alarm.position)%")
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
                            .disabled(connectivityMonitor.isOffline)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedAlarmForEdit = alarm
                        }
                        .deleteDisabled(connectivityMonitor.isOffline)
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
            .safeAreaInset(edge: .top) {
                Color.clear
                    .frame(height: 6)
            }
            .navigationTitle("Alarms")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showingTimeShift = true }) {
                        Image(systemName: "clock.arrow.2.circlepath")
                    }
                    .disabled(viewModel.alarms.isEmpty)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingNewAlarmForm = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingNewAlarmForm) {
                let formVM = AlarmFormViewModel()
                let devicePickerVM = DevicePickerViewModel()
                AlarmFormView(
                    viewModel: formVM,
                    haService: haService,
                    devicePickerViewModel: devicePickerVM
                )
                    .onDisappear {
                        Task {
                            await viewModel.loadAlarms()
                        }
                    }
            }
            .sheet(item: $selectedAlarmForEdit) { alarm in
                let formVM = AlarmFormViewModel()
                let devicePickerVM = DevicePickerViewModel()
                return AlarmFormView(
                    viewModel: formVM,
                    haService: haService,
                    devicePickerViewModel: devicePickerVM
                )
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
                if let haService {
                    viewModel.setupService(haService: haService)
                }
                await viewModel.loadAlarms()
            }
        }
    }

    @ViewBuilder
    private var timeShiftSheet: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Direction", selection: $shiftDirection) {
                    ForEach(ShiftDirection.allCases, id: \.self) { dir in
                        Text(dir.rawValue).tag(dir)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                DatePicker("", selection: $shiftDate, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
            }
            .navigationTitle("Shift Alarms")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        shiftDate = Calendar.current.date(byAdding: .minute, value: 2, to: Calendar.current.startOfDay(for: Date())) ?? Calendar.current.startOfDay(for: Date())
                        shiftDirection = .forward
                        showingTimeShift = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        let components = Calendar.current.dateComponents([.hour, .minute], from: shiftDate)
                        let totalMinutes = ((components.hour ?? 0) * 60 + (components.minute ?? 0))
                            * (shiftDirection == .forward ? 1 : -1)
                        shiftDate = Calendar.current.date(byAdding: .minute, value: 2, to: Calendar.current.startOfDay(for: Date())) ?? Calendar.current.startOfDay(for: Date())
                        shiftDirection = .forward
                        showingTimeShift = false
                        Task { await viewModel.shiftAlarms(byMinutes: totalMinutes) }
                    }
                    .disabled(connectivityMonitor.isOffline)
                }
            }
        }
        .presentationDetents([.height(340)])
        .presentationDragIndicator(.visible)
    }
}
