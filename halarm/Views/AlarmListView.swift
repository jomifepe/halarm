import SwiftUI

private enum ShiftDirection: String, CaseIterable {
    case forward = "Later"
    case backward = "Earlier"
}

struct AlarmListView: View {
    @State var viewModel: AlarmListViewModel
    @State private var showingNewAlarmForm = false
    @State private var selectedAlarmForEdit: Alarm?
    @State private var showingTimeShift = false
    @State private var shiftDate: Date = Calendar.current.startOfDay(for: Date())
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
                AlarmFormView(viewModel: formVM, haService: haService)
                    .onDisappear {
                        Task {
                            await viewModel.loadAlarms()
                        }
                    }
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

    @ViewBuilder
    private var timeShiftSheet: some View {
        VStack(spacing: 16) {
            Text("Shift Alarms")
                .font(.headline)
                .padding(.top, 20)

            Picker("Direction", selection: $shiftDirection) {
                ForEach(ShiftDirection.allCases, id: \.self) { dir in
                    Text(dir.rawValue).tag(dir)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            DatePicker("", selection: $shiftDate, displayedComponents: .hourAndMinute)
                .datePickerStyle(.wheel)
                .labelsHidden()

            Button("Apply") {
                let components = Calendar.current.dateComponents([.hour, .minute], from: shiftDate)
                let totalMinutes = ((components.hour ?? 0) * 60 + (components.minute ?? 0))
                    * (shiftDirection == .forward ? 1 : -1)
                shiftDate = Calendar.current.startOfDay(for: Date())
                shiftDirection = .forward
                showingTimeShift = false
                Task { await viewModel.shiftAlarms(byMinutes: totalMinutes) }
            }
            .buttonStyle(.borderedProminent)
            .padding(.bottom, 20)
        }
        .presentationDetents([.height(380)])
        .presentationDragIndicator(.visible)
    }
}
