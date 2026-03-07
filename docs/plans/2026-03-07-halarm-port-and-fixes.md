# HAlarm Port & Service Injection Fix Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Port complete HAlarm implementation from halarm_bak to halarm project, fix service injection issues, and verify the app compiles and runs.

**Architecture:** The app uses a clean architecture with Models → Services (HAService actor + AutomationMapper) → ViewModels (@Observable) → Views (SwiftUI). HAService is a stateless actor providing REST API access to Home Assistant. All ViewModels are @Observable and receive HAService via dependency injection from the app entry point. SettingsStore manages persistent configuration via UserDefaults.

**Tech Stack:** Swift 6, SwiftUI (iOS 18+), async/await, URLSession, no external dependencies

---

## Phase 1: Prepare Project Structure

### Task 1: Create directory structure in halarm project

**Files:**
- Create: `halarm/Models/`
- Create: `halarm/Services/`
- Create: `halarm/ViewModels/`
- Create: `halarm/Views/`

**Steps:**

1. Create the directories:
```bash
mkdir -p /Users/jmfp/dev/misc/halarm/halarm/Models
mkdir -p /Users/jmfp/dev/misc/halarm/halarm/Services
mkdir -p /Users/jmfp/dev/misc/halarm/halarm/ViewModels
mkdir -p /Users/jmfp/dev/misc/halarm/halarm/Views
```

2. Verify directories exist:
```bash
ls -la /Users/jmfp/dev/misc/halarm/halarm/
```
Expected: See `Models`, `Services`, `ViewModels`, `Views` directories

3. Commit:
```bash
cd /Users/jmfp/dev/misc/halarm
git add -A
git commit -m "chore: create project directory structure"
```

---

## Phase 2: Port Models

### Task 2: Port Weekday.swift

**Files:**
- Create: `halarm/Models/Weekday.swift`

**Source:** `/Users/jmfp/dev/misc/halarm_bak/.worktrees/halarm-implementation/HAlarm/Models/Weekday.swift`

**Steps:**

1. Copy the file:
```bash
cp /Users/jmfp/dev/misc/halarm_bak/.worktrees/halarm-implementation/HAlarm/Models/Weekday.swift /Users/jmfp/dev/misc/halarm/halarm/Models/Weekday.swift
```

2. Verify it exists and has content:
```bash
head -10 /Users/jmfp/dev/misc/halarm/halarm/Models/Weekday.swift
```
Expected: Should see `enum Weekday: String, CaseIterable`

3. Commit:
```bash
cd /Users/jmfp/dev/misc/halarm
git add halarm/Models/Weekday.swift
git commit -m "feat: port Weekday model"
```

### Task 3: Port CoverEntity.swift

**Files:**
- Create: `halarm/Models/CoverEntity.swift`

**Source:** `/Users/jmfp/dev/misc/halarm_bak/.worktrees/halarm-implementation/HAlarm/Models/CoverEntity.swift`

**Steps:**

1. Copy the file:
```bash
cp /Users/jmfp/dev/misc/halarm_bak/.worktrees/halarm-implementation/HAlarm/Models/CoverEntity.swift /Users/jmfp/dev/misc/halarm/halarm/Models/CoverEntity.swift
```

2. Verify:
```bash
cat /Users/jmfp/dev/misc/halarm/halarm/Models/CoverEntity.swift
```
Expected: Should see `struct CoverEntity: Identifiable, Hashable, Codable`

3. Commit:
```bash
cd /Users/jmfp/dev/misc/halarm
git add halarm/Models/CoverEntity.swift
git commit -m "feat: port CoverEntity model"
```

### Task 4: Port Alarm.swift

**Files:**
- Create: `halarm/Models/Alarm.swift`

**Source:** `/Users/jmfp/dev/misc/halarm_bak/.worktrees/halarm-implementation/HAlarm/Models/Alarm.swift`

**Steps:**

1. Copy the file:
```bash
cp /Users/jmfp/dev/misc/halarm_bak/.worktrees/halarm-implementation/HAlarm/Models/Alarm.swift /Users/jmfp/dev/misc/halarm/halarm/Models/Alarm.swift
```

2. Verify:
```bash
grep "struct Alarm" /Users/jmfp/dev/misc/halarm/halarm/Models/Alarm.swift
```
Expected: Should see `struct Alarm: Identifiable, Hashable, Codable`

3. Commit:
```bash
cd /Users/jmfp/dev/misc/halarm
git add halarm/Models/Alarm.swift
git commit -m "feat: port Alarm model"
```

---

## Phase 3: Port Services

### Task 5: Port HAService.swift

**Files:**
- Create: `halarm/Services/HAService.swift`

**Source:** `/Users/jmfp/dev/misc/halarm_bak/.worktrees/halarm-implementation/HAlarm/Services/HAService.swift`

**Steps:**

1. Copy the file:
```bash
cp /Users/jmfp/dev/misc/halarm_bak/.worktrees/halarm-implementation/HAlarm/Services/HAService.swift /Users/jmfp/dev/misc/halarm/halarm/Services/HAService.swift
```

2. Verify:
```bash
grep "actor HAService" /Users/jmfp/dev/misc/halarm/halarm/Services/HAService.swift
```
Expected: Should see `actor HAService {`

3. Commit:
```bash
cd /Users/jmfp/dev/misc/halarm
git add halarm/Services/HAService.swift
git commit -m "feat: port HAService actor with REST API client"
```

### Task 6: Port AutomationMapper.swift

**Files:**
- Create: `halarm/Services/AutomationMapper.swift`

**Source:** `/Users/jmfp/dev/misc/halarm_bak/.worktrees/halarm-implementation/HAlarm/Services/AutomationMapper.swift`

**Steps:**

1. Copy the file:
```bash
cp /Users/jmfp/dev/misc/halarm_bak/.worktrees/halarm-implementation/HAlarm/Services/AutomationMapper.swift /Users/jmfp/dev/misc/halarm/halarm/Services/AutomationMapper.swift
```

2. Verify:
```bash
grep "enum AutomationMapper" /Users/jmfp/dev/misc/halarm/halarm/Services/AutomationMapper.swift
```
Expected: Should see `enum AutomationMapper {`

3. Commit:
```bash
cd /Users/jmfp/dev/misc/halarm
git add halarm/Services/AutomationMapper.swift
git commit -m "feat: port AutomationMapper for model conversion"
```

### Task 7: Port and FIX SettingsStore.swift

**Files:**
- Create: `halarm/Services/SettingsStore.swift`

**Source:** `/Users/jmfp/dev/misc/halarm_bak/.worktrees/halarm-implementation/HAlarm/Services/SettingsStore.swift` (with modifications)

**Steps:**

1. Copy the file:
```bash
cp /Users/jmfp/dev/misc/halarm_bak/.worktrees/halarm-implementation/HAlarm/Services/SettingsStore.swift /Users/jmfp/dev/misc/halarm/halarm/Services/SettingsStore.swift
```

2. Edit to add the missing `.shared` singleton. Add after the class declaration:

**File: `halarm/Services/SettingsStore.swift`**

Read the file first to see current content, then add this after the `clear()` method and before the closing brace:

```swift

    static let shared = SettingsStore()
}
```

Complete final version should look like:
```swift
import Foundation

@Observable
final class SettingsStore {
    @ObservationIgnored
    private let defaults = UserDefaults.standard

    private static let baseURLKey = "halarm_baseURL"
    private static let tokenKey = "halarm_token"

    var baseURL: String {
        get { defaults.string(forKey: Self.baseURLKey) ?? "" }
        set { defaults.set(newValue, forKey: Self.baseURLKey) }
    }

    var token: String {
        get { defaults.string(forKey: Self.tokenKey) ?? "" }
        set { defaults.set(newValue, forKey: Self.tokenKey) }
    }

    var isConfigured: Bool {
        !baseURL.trimmingCharacters(in: .whitespaces).isEmpty &&
        !token.trimmingCharacters(in: .whitespaces).isEmpty
    }

    func clear() {
        baseURL = ""
        token = ""
    }

    static let shared = SettingsStore()
}
```

3. Verify:
```bash
grep "static let shared" /Users/jmfp/dev/misc/halarm/halarm/Services/SettingsStore.swift
```
Expected: Should see `static let shared = SettingsStore()`

4. Commit:
```bash
cd /Users/jmfp/dev/misc/halarm
git add halarm/Services/SettingsStore.swift
git commit -m "feat: port SettingsStore and add shared singleton"
```

---

## Phase 4: Port ViewModels

### Task 8: Port AlarmListViewModel.swift

**Files:**
- Create: `halarm/ViewModels/AlarmListViewModel.swift`

**Source:** `/Users/jmfp/dev/misc/halarm_bak/.worktrees/halarm-implementation/HAlarm/HAlarm/ViewModels/AlarmListViewModel.swift`

**Steps:**

1. Copy the file:
```bash
cp /Users/jmfp/dev/misc/halarm_bak/.worktrees/halarm-implementation/HAlarm/HAlarm/ViewModels/AlarmListViewModel.swift /Users/jmfp/dev/misc/halarm/halarm/ViewModels/AlarmListViewModel.swift
```

2. Verify:
```bash
grep "class AlarmListViewModel" /Users/jmfp/dev/misc/halarm/halarm/ViewModels/AlarmListViewModel.swift
```
Expected: Should see `final class AlarmListViewModel`

3. Commit:
```bash
cd /Users/jmfp/dev/misc/halarm
git add halarm/ViewModels/AlarmListViewModel.swift
git commit -m "feat: port AlarmListViewModel"
```

### Task 9: Port AlarmFormViewModel.swift

**Files:**
- Create: `halarm/ViewModels/AlarmFormViewModel.swift`

**Source:** `/Users/jmfp/dev/misc/halarm_bak/.worktrees/halarm-implementation/HAlarm/HAlarm/ViewModels/AlarmFormViewModel.swift`

**Steps:**

1. Copy the file:
```bash
cp /Users/jmfp/dev/misc/halarm_bak/.worktrees/halarm-implementation/HAlarm/HAlarm/ViewModels/AlarmFormViewModel.swift /Users/jmfp/dev/misc/halarm/halarm/ViewModels/AlarmFormViewModel.swift
```

2. Verify:
```bash
grep "class AlarmFormViewModel" /Users/jmfp/dev/misc/halarm/halarm/ViewModels/AlarmFormViewModel.swift
```
Expected: Should see `final class AlarmFormViewModel`

3. Commit:
```bash
cd /Users/jmfp/dev/misc/halarm
git add halarm/ViewModels/AlarmFormViewModel.swift
git commit -m "feat: port AlarmFormViewModel"
```

### Task 10: Port DevicePickerViewModel.swift

**Files:**
- Create: `halarm/ViewModels/DevicePickerViewModel.swift`

**Source:** `/Users/jmfp/dev/misc/halarm_bak/.worktrees/halarm-implementation/HAlarm/HAlarm/ViewModels/DevicePickerViewModel.swift`

**Steps:**

1. Copy the file:
```bash
cp /Users/jmfp/dev/misc/halarm_bak/.worktrees/halarm-implementation/HAlarm/HAlarm/ViewModels/DevicePickerViewModel.swift /Users/jmfp/dev/misc/halarm/halarm/ViewModels/DevicePickerViewModel.swift
```

2. Verify:
```bash
grep "class DevicePickerViewModel" /Users/jmfp/dev/misc/halarm/halarm/ViewModels/DevicePickerViewModel.swift
```
Expected: Should see `final class DevicePickerViewModel`

3. Commit:
```bash
cd /Users/jmfp/dev/misc/halarm
git add halarm/ViewModels/DevicePickerViewModel.swift
git commit -m "feat: port DevicePickerViewModel"
```

### Task 11: Port SettingsViewModel.swift

**Files:**
- Create: `halarm/ViewModels/SettingsViewModel.swift`

**Source:** `/Users/jmfp/dev/misc/halarm_bak/.worktrees/halarm-implementation/HAlarm/HAlarm/ViewModels/SettingsViewModel.swift`

**Steps:**

1. Copy the file:
```bash
cp /Users/jmfp/dev/misc/halarm_bak/.worktrees/halarm-implementation/HAlarm/HAlarm/ViewModels/SettingsViewModel.swift /Users/jmfp/dev/misc/halarm/halarm/ViewModels/SettingsViewModel.swift
```

2. Verify:
```bash
grep "class SettingsViewModel" /Users/jmfp/dev/misc/halarm/halarm/ViewModels/SettingsViewModel.swift
```
Expected: Should see `final class SettingsViewModel`

3. Commit:
```bash
cd /Users/jmfp/dev/misc/halarm
git add halarm/ViewModels/SettingsViewModel.swift
git commit -m "feat: port SettingsViewModel"
```

---

## Phase 5: Port Views

### Task 12: Port WeekdayPickerView.swift

**Files:**
- Create: `halarm/Views/WeekdayPickerView.swift`

**Source:** `/Users/jmfp/dev/misc/halarm_bak/.worktrees/halarm-implementation/HAlarm/HAlarm/Views/WeekdayPickerView.swift`

**Steps:**

1. Copy the file:
```bash
cp /Users/jmfp/dev/misc/halarm_bak/.worktrees/halarm-implementation/HAlarm/HAlarm/Views/WeekdayPickerView.swift /Users/jmfp/dev/misc/halarm/halarm/Views/WeekdayPickerView.swift
```

2. Verify:
```bash
grep "struct WeekdayPickerView" /Users/jmfp/dev/misc/halarm/halarm/Views/WeekdayPickerView.swift
```
Expected: Should see `struct WeekdayPickerView: View`

3. Commit:
```bash
cd /Users/jmfp/dev/misc/halarm
git add halarm/Views/WeekdayPickerView.swift
git commit -m "feat: port WeekdayPickerView component"
```

### Task 13: Port DevicePickerView.swift

**Files:**
- Create: `halarm/Views/DevicePickerView.swift`

**Source:** `/Users/jmfp/dev/misc/halarm_bak/.worktrees/halarm-implementation/HAlarm/HAlarm/Views/DevicePickerView.swift`

**Steps:**

1. Copy the file:
```bash
cp /Users/jmfp/dev/misc/halarm_bak/.worktrees/halarm-implementation/HAlarm/HAlarm/Views/DevicePickerView.swift /Users/jmfp/dev/misc/halarm/halarm/Views/DevicePickerView.swift
```

2. Verify:
```bash
grep "struct DevicePickerView" /Users/jmfp/dev/misc/halarm/halarm/Views/DevicePickerView.swift
```
Expected: Should see `struct DevicePickerView: View`

3. Commit:
```bash
cd /Users/jmfp/dev/misc/halarm
git add halarm/Views/DevicePickerView.swift
git commit -m "feat: port DevicePickerView"
```

### Task 14: Port AlarmFormView.swift

**Files:**
- Create: `halarm/Views/AlarmFormView.swift`

**Source:** `/Users/jmfp/dev/misc/halarm_bak/.worktrees/halarm-implementation/HAlarm/HAlarm/Views/AlarmFormView.swift`

**Steps:**

1. Copy the file:
```bash
cp /Users/jmfp/dev/misc/halarm_bak/.worktrees/halarm-implementation/HAlarm/HAlarm/Views/AlarmFormView.swift /Users/jmfp/dev/misc/halarm/halarm/Views/AlarmFormView.swift
```

2. Verify:
```bash
grep "struct AlarmFormView" /Users/jmfp/dev/misc/halarm/halarm/Views/AlarmFormView.swift
```
Expected: Should see `struct AlarmFormView: View`

3. Commit:
```bash
cd /Users/jmfp/dev/misc/halarm
git add halarm/Views/AlarmFormView.swift
git commit -m "feat: port AlarmFormView"
```

### Task 15: Port SettingsView.swift

**Files:**
- Create: `halarm/Views/SettingsView.swift`

**Source:** `/Users/jmfp/dev/misc/halarm_bak/.worktrees/halarm-implementation/HAlarm/HAlarm/Views/SettingsView.swift`

**Steps:**

1. Copy the file:
```bash
cp /Users/jmfp/dev/misc/halarm_bak/.worktrees/halarm-implementation/HAlarm/HAlarm/Views/SettingsView.swift /Users/jmfp/dev/misc/halarm/halarm/Views/SettingsView.swift
```

2. Verify:
```bash
grep "struct SettingsView" /Users/jmfp/dev/misc/halarm/halarm/Views/SettingsView.swift
```
Expected: Should see `struct SettingsView: View`

3. Commit:
```bash
cd /Users/jmfp/dev/misc/halarm
git add halarm/Views/SettingsView.swift
git commit -m "feat: port SettingsView"
```

### Task 16: Port AlarmListView.swift

**Files:**
- Create: `halarm/Views/AlarmListView.swift`

**Source:** `/Users/jmfp/dev/misc/halarm_bak/.worktrees/halarm-implementation/HAlarm/HAlarm/Views/AlarmListView.swift`

**Steps:**

1. Copy the file:
```bash
cp /Users/jmfp/dev/misc/halarm_bak/.worktrees/halarm-implementation/HAlarm/HAlarm/Views/AlarmListView.swift /Users/jmfp/dev/misc/halarm/halarm/Views/AlarmListView.swift
```

2. Verify:
```bash
grep "struct AlarmListView" /Users/jmfp/dev/misc/halarm/halarm/Views/AlarmListView.swift
```
Expected: Should see `struct AlarmListView: View`

3. Commit:
```bash
cd /Users/jmfp/dev/misc/halarm
git add halarm/Views/AlarmListView.swift
git commit -m "feat: port AlarmListView"
```

---

## Phase 6: Fix Service Injection & App Entry Point

### Task 17: Update ContentView.swift (temporary - will be deleted)

**Files:**
- Modify: `halarm/ContentView.swift`

**Steps:**

1. We'll keep this as is for now but it will be replaced. Just verify the file exists:
```bash
ls -la /Users/jmfp/dev/misc/halarm/halarm/ContentView.swift
```
Expected: File should exist

2. No commit needed yet - we'll update this in the next task

### Task 18: Rewrite halarmApp.swift with proper service injection

**Files:**
- Modify: `halarm/halarmApp.swift`

**Current:** Basic app entry with ContentView
**Target:** Proper initialization with HAService and ViewModels

**Steps:**

1. Read current file:
```bash
cat /Users/jmfp/dev/misc/halarm/halarm/halarmApp.swift
```

2. Replace entire content with:

```swift
import SwiftUI

@main
struct halarmApp: App {
    @State private var settingsStore = SettingsStore.shared
    @State private var haService: HAService?
    @State private var alarmListViewModel = AlarmListViewModel()

    var body: some Scene {
        WindowGroup {
            if settingsStore.isConfigured {
                AlarmListView(viewModel: alarmListViewModel)
                    .task {
                        let service = HAService(baseURL: settingsStore.baseURL, token: settingsStore.token)
                        haService = service
                        alarmListViewModel.setupService(haService: service)
                    }
            } else {
                SettingsView(viewModel: SettingsViewModel(settingsStore: settingsStore))
                    .task {
                        await Task.sleep(1_000_000_000) // Allow settings to be saved
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
```

3. Verify the file was updated:
```bash
grep "halarmApp" /Users/jmfp/dev/misc/halarm/halarm/halarmApp.swift
```
Expected: Should see `struct halarmApp: App`

4. Commit:
```bash
cd /Users/jmfp/dev/misc/halarm
git add halarm/halarmApp.swift
git commit -m "fix: rewrite app entry point with proper service injection"
```

### Task 19: Fix AlarmFormView service injection

**Files:**
- Modify: `halarm/Views/AlarmFormView.swift`

**Issue:** AlarmFormViewModel and DevicePickerViewModel don't receive HAService

**Current Code (line ~28):**
```swift
DevicePickerView(viewModel: DevicePickerViewModel(), selectedDevice: $viewModel.selectedDevice)
    .task {
        await viewModel.loadDevices()
    }
```

**Problem:** DevicePickerViewModel created without HAService, so loadDevices() will fail

**Steps:**

1. Read the current file to see exact line numbers:
```bash
cat -n /Users/jmfp/dev/misc/halarm/halarm/Views/AlarmFormView.swift | grep -A 5 "DevicePickerView"
```

2. We need to refactor AlarmFormView to accept HAService as a parameter. First, let me check what the current structure is and see if we need to pass it through. Actually, looking at the code, the issue is more complex. Let me provide the corrected AlarmFormView:

Replace the entire file with this corrected version:

```swift
import SwiftUI

struct AlarmFormView: View {
    @State var viewModel: AlarmFormViewModel
    @Environment(\.dismiss) var dismiss
    @State private var isSaving = false

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
                    NavigationLink(destination: {
                        let devicePickerVM = DevicePickerViewModel()
                        if let service = haService {
                            devicePickerVM.setupService(service)
                        }
                        return DevicePickerView(viewModel: devicePickerVM, selectedDevice: $viewModel.selectedDevice)
                            .task {
                                await devicePickerVM.loadDevices()
                            }
                    }) {
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

                    Slider(value: Double($viewModel.position).wrappedValue, in: 0...100, step: 1)
                        .onChange(of: $viewModel.position) { oldValue, newValue in
                            viewModel.position = Int(newValue)
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
}
```

3. Verify the file was updated:
```bash
grep "private let haService" /Users/jmfp/dev/misc/halarm/halarm/Views/AlarmFormView.swift
```
Expected: Should see `private let haService: HAService?`

4. Commit:
```bash
cd /Users/jmfp/dev/misc/halarm
git add halarm/Views/AlarmFormView.swift
git commit -m "fix: add HAService injection to AlarmFormView and DevicePickerViewModel"
```

### Task 20: Fix AlarmListView service injection

**Files:**
- Modify: `halarm/Views/AlarmListView.swift`

**Issue:** AlarmFormViewModel needs HAService when created in sheet

**Steps:**

1. Replace the entire AlarmListView.swift file:

```swift
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
                if viewModel.isLoading {
                    ProgressView()
                } else if let error = viewModel.errorMessage {
                    Text("Error: \(error)")
                        .foregroundColor(.red)
                } else if viewModel.alarms.isEmpty {
                    Text("No alarms yet")
                        .foregroundColor(.secondary)
                } else {
                    ForEach($viewModel.alarms) { $alarm in
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

                            Toggle("", isOn: $alarm.isEnabled)
                                .onChange(of: alarm.isEnabled) { oldValue, newValue in
                                    Task {
                                        await viewModel.toggleAlarm(id: alarm.id, enabled: newValue)
                                    }
                                }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedAlarmForEdit = alarm
                        }
                    }
                    .onDelete { indexSet in
                        Task {
                            for index in indexSet {
                                let alarm = viewModel.alarms[index]
                                await viewModel.deleteAlarm(id: alarm.id)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Alarms")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingNewAlarmForm = true }) {
                        Image(systemName: "plus")
                    }
                }

                ToolbarItem(placement: .secondaryAction) {
                    Button(action: { showingSettings = true }) {
                        Image(systemName: "gear")
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
            .task {
                await viewModel.loadAlarms()
            }
        }
    }
}
```

2. Verify the file was updated:
```bash
grep "private let haService" /Users/jmfp/dev/misc/halarm/halarm/Views/AlarmListView.swift
```
Expected: Should see `private let haService: HAService?`

3. Commit:
```bash
cd /Users/jmfp/dev/misc/halarm
git add halarm/Views/AlarmListView.swift
git commit -m "fix: add HAService injection to AlarmListView"
```

### Task 21: Update halarmApp.swift again with corrected initialization

**Files:**
- Modify: `halarm/halarmApp.swift`

**Issue:** Need to pass haService to AlarmListView

**Steps:**

1. Replace the entire halarmApp.swift with this corrected version:

```swift
import SwiftUI

@main
struct halarmApp: App {
    @State private var settingsStore = SettingsStore.shared
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
```

2. Verify:
```bash
grep "AlarmListView" /Users/jmfp/dev/misc/halarm/halarm/halarmApp.swift
```
Expected: Should see `AlarmListView(viewModel: alarmListViewModel, haService: haService)`

3. Commit:
```bash
cd /Users/jmfp/dev/misc/halarm
git add halarm/halarmApp.swift
git commit -m "fix: pass haService to AlarmListView initialization"
```

---

## Phase 7: Remove old template files

### Task 22: Delete ContentView.swift

**Files:**
- Delete: `halarm/ContentView.swift`

**Steps:**

1. Delete the file:
```bash
rm /Users/jmfp/dev/misc/halarm/halarm/ContentView.swift
```

2. Verify it's deleted:
```bash
ls -la /Users/jmfp/dev/misc/halarm/halarm/ContentView.swift
```
Expected: `No such file or directory`

3. Remove from Xcode project (check that it's no longer referenced). In Xcode, you may need to remove it from the project target if it still appears.

4. Commit:
```bash
cd /Users/jmfp/dev/misc/halarm
git add -A
git commit -m "chore: remove template ContentView"
```

---

## Phase 8: Build and Verify

### Task 23: Build the project in Xcode

**Files:**
- Build: `halarm.xcodeproj`

**Steps:**

1. Open the project in Xcode:
```bash
open /Users/jmfp/dev/misc/halarm/halarm.xcodeproj
```

2. In Xcode:
   - Select the `halarm` scheme (top left dropdown)
   - Select an iOS simulator (iPhone 15 or later recommended)
   - Product → Build (⌘B)

3. Expected: Build succeeds with no errors or warnings

4. If there are errors:
   - Common issues:
     - Missing files in Xcode project navigator (drag files from Finder to Xcode)
     - File encoding issues (change to UTF-8 in File Inspector)
     - Module import issues (ensure all imports are correct)
   - Document any errors found and fix them

5. Once build succeeds, commit:
```bash
cd /Users/jmfp/dev/misc/halarm
git add -A
git commit -m "build: successful project build with all components"
```

### Task 24: Run the app on simulator

**Files:**
- Run: `halarm` target

**Steps:**

1. In Xcode with simulator selected:
   - Product → Run (⌘R)

2. Expected behaviors:
   - App launches on simulator
   - If not configured: SettingsView appears with URL and token fields
   - User can enter URL and token
   - Test Connection button works
   - After successful connection: AlarmListView appears
   - AlarmListView shows "No alarms yet" message

3. If app crashes:
   - Check Console output (View → Debug Area → Show Console)
   - Look for error messages
   - Common crashes:
     - URLSession issues: Check HAService init
     - Binding issues: Check @State variables
     - Missing environment objects: Check property wrappers
   - Fix errors and rebuild

4. If successful, commit:
```bash
cd /Users/jmfp/dev/misc/halarm
git add -A
git commit -m "test: app runs successfully on simulator"
```

### Task 25: Test basic flow

**Files:**
- Test: All integrated components

**Steps:**

1. In running simulator:
   - Open Settings
   - Enter Home Assistant URL (e.g., `http://homeassistant.local:8123`)
   - Enter a valid long-lived access token from HA
   - Tap "Test Connection"
   - Expected: "✓ Connection successful" message appears

2. Tap Done:
   - Expected: Return to AlarmListView
   - Settings saved to UserDefaults

3. Tap + button:
   - Expected: AlarmFormView opens with form
   - Fields show: Label, Time (currently set to 7:00), Days (Mon-Fri), Device selector, Position (100%)

4. Tap Device field:
   - Expected: DevicePickerView loads with available cover entities from HA
   - Can search by name or entity_id
   - Can select a device

5. Adjust settings and tap Save:
   - Expected: App creates automation in HA and returns to list
   - New alarm appears in list

6. If any step fails:
   - Check error messages in app
   - Check HA logs for automation creation
   - Check HAService methods for correct API endpoints
   - Debug and fix issues

7. Final commit:
```bash
cd /Users/jmfp/dev/misc/halarm
git add -A
git commit -m "test: verify complete app workflow end-to-end"
```

---

## Summary

This plan ports 18 Swift files from halarm_bak to halarm, fixes critical service injection bugs, and verifies the complete implementation. Key changes:

- **Fixed:** SettingsStore.shared singleton
- **Fixed:** HAService dependency injection to all ViewModels
- **Fixed:** Proper initialization in app entry point
- **Fixed:** AlarmFormView and AlarmListView service passing
- **Verified:** Complete build and basic workflow

Total commits: 25 (frequent, atomic)
Estimated time: 1-2 hours depending on any compilation issues

---

**Next Step:** Execute this plan using superpowers:executing-plans or superpowers:subagent-driven-development
