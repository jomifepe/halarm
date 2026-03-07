import SwiftUI

struct AlarmFormView: View {
    @State var viewModel: AlarmFormViewModel
    @Environment(\.dismiss) var dismiss
    @State private var isSaving = false
    @State private var devicePickerVM = DevicePickerViewModel()

    private let haService: HAService?

    init(viewModel: AlarmFormViewModel = AlarmFormViewModel(), haService: HAService? = nil) {
        self._viewModel = State(initialValue: viewModel)
        self.haService = haService
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Alarm Details") {
                    TextField("Label (optional)", text: $viewModel.label)

                    HStack {
                        Text("Time")
                        Spacer()
                        DatePicker("", selection: timeBinding, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                    }
                }

                Section {
                    WeekdayPickerView(selectedWeekdays: $viewModel.weekdays)
                }

                Section("Blind Settings") {
                    NavigationLink(destination:
                        DevicePickerView(viewModel: devicePickerVM, selectedDevice: $viewModel.selectedDevice)
                            .task {
                                await devicePickerVM.loadDevices()
                            }
                    ) {
                        HStack {
                            Text("Device")
                            Spacer()
                            if let device = viewModel.selectedDevice {
                                Text(device.name)
                                    .foregroundColor(.secondary)
                            } else {
                                Text("Select device")
                                    .foregroundColor(.red)
                            }
                        }
                    }

                    HStack {
                        Text("Position")
                        Spacer()
                        Text("\(viewModel.position)%")
                            .foregroundColor(.secondary)
                    }

                    Slider(value: positionBinding, in: 0...100, step: 1)

                    HStack(spacing: 0) {
                        Text("0% = Closed")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("100% = Open")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                if let error = viewModel.errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("New Alarm")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("Save") {
                            isSaving = true
                            Task {
                                defer { isSaving = false }
                                do {
                                    try await viewModel.saveAlarm()
                                    dismiss()
                                } catch {
                                    viewModel.errorMessage = error.localizedDescription
                                }
                            }
                        }
                        .disabled(viewModel.selectedDevice == nil)
                    }
                }
            }
            .task {
                if let service = haService {
                    viewModel.setupService(service)
                    devicePickerVM.setupService(service)
                    await viewModel.loadDevices()
                    await devicePickerVM.loadDevices()
                }
            }
        }
    }

    private var timeBinding: Binding<Date> {
        Binding(
            get: {
                var components = DateComponents()
                components.hour = viewModel.hour
                components.minute = viewModel.minute
                return Calendar.current.date(from: components) ?? Date()
            },
            set: { newDate in
                let components = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                viewModel.hour = components.hour ?? 0
                viewModel.minute = components.minute ?? 0
            }
        )
    }

    private var positionBinding: Binding<Double> {
        Binding(
            get: { Double(viewModel.position) },
            set: { viewModel.position = Int($0) }
        )
    }
}
