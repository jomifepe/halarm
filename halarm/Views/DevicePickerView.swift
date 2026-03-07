import SwiftUI

struct DevicePickerView: View {
    @State var viewModel: DevicePickerViewModel
    @Binding var selectedDevice: CoverEntity?
    @Environment(\.dismiss) var dismiss

    var body: some View {
        List {
            if viewModel.isLoading {
                ProgressView()
            } else if let error = viewModel.errorMessage {
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
