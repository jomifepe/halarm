import SwiftUI

@MainActor
struct DevicePickerView: View {
    @State var viewModel: DevicePickerViewModel
    @State private var connectivityMonitor: ConnectivityMonitor
    @Binding var selectedDevice: CoverEntity?
    @Environment(\.dismiss) var dismiss

    init(viewModel: DevicePickerViewModel, selectedDevice: Binding<CoverEntity?>) {
        self._viewModel = State(initialValue: viewModel)
        self._connectivityMonitor = State(initialValue: ConnectivityMonitor.shared)
        self._selectedDevice = selectedDevice
    }

    var body: some View {
        List {
            if let message = connectivityMonitor.statusMessage {
                Label(message, systemImage: "wifi.exclamationmark")
                    .foregroundColor(.orange)
            }

            if let error = viewModel.errorMessage,
               !viewModel.filteredDevices.isEmpty,
               error != connectivityMonitor.statusMessage {
                Section {
                    Text(error)
                        .foregroundColor(.secondary)
                }
            }

            if viewModel.isLoading {
                ProgressView()
            } else if let error = viewModel.errorMessage,
                      viewModel.filteredDevices.isEmpty,
                      error != connectivityMonitor.statusMessage {
                Text("Error: \(error)")
                    .foregroundColor(.red)
            } else if viewModel.filteredDevices.isEmpty {
                Text("No devices found")
                    .foregroundColor(.secondary)
            } else {
                ForEach(viewModel.filteredDevices) { device in
                    Button(action: {
                        selectedDevice = device
                        dismiss()
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(device.name)
                                    .foregroundColor(.primary)
                                Text(device.id)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            if selectedDevice?.id == device.id {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
        }
        .searchable(text: $viewModel.searchText, prompt: "Search devices")
        .navigationTitle("Select Device")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadDevices()
        }
    }
}
