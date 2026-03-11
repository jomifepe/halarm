import SwiftUI

struct SettingsView: View {
    @State var viewModel: SettingsViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Home Assistant") {
                    TextField("Base URL", text: $viewModel.baseURL)
                        .textInputAutocapitalization(.none)
                        .keyboardType(.URL)

                    SecureField("Long-lived Access Token", text: $viewModel.token)
                }

                Section("Preferences") {
                    Toggle("Remember last alarm settings", isOn: Binding(
                        get: { SettingsStore.shared.persistLastAlarmConfig },
                        set: { SettingsStore.shared.persistLastAlarmConfig = $0 }
                    ))
                }

                Section {
                    Button(action: {
                        Task {
                            await viewModel.testConnection()
                        }
                    }) {
                        HStack {
                            Text("Test Connection")
                            if viewModel.isTestingConnection {
                                Spacer()
                                ProgressView()
                            }
                        }
                    }
                    .disabled(viewModel.isTestingConnection)
                }

                if let result = viewModel.testResult {
                    Section {
                        Text(result)
                            .foregroundColor(.green)
                    }
                }

                if let error = viewModel.testError {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        viewModel.saveSettings()
                        dismiss()
                    }
                }
            }
        }
    }
}
