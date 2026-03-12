import Foundation

enum AutomationMapper {
    nonisolated static func toHA(from alarm: Alarm) -> HAAutomation {
        let automationId = alarm.id.replacingOccurrences(of: "halarm_", with: "")

        // Create trigger in the new format (HA 2026.2.2)
        let trigger = HATrigger(
            trigger: "time",  // Changed from "platform"
            at: String(format: "%02d:%02d:00", alarm.hour, alarm.minute)
        )

        let weekdayValues = alarm.weekdays
            .sorted { $0.rawValue < $1.rawValue }
            .map { $0.rawValue }

        // Create condition for weekdays
        // No condition if all days (7) or no days (0) selected
        // If no days: runs once and is deleted; if all days: runs daily
        let conditions: [HACondition]? = (alarm.weekdays.isEmpty || alarm.weekdays.count == 7) ? nil : [
            HACondition(
                condition: "time",
                weekday: weekdayValues
            )
        ]

        // Create action in the new format
        let action = HAAction(
            action: "cover.set_cover_position",  // Changed from "service"
            target: HATarget(entity_id: alarm.device.id),
            data: HAData(position: alarm.position)
        )

        // Store alarm metadata in description as JSON for fetch/reconstruct
        let metadata: [String: Any] = [
            "label": alarm.label,
            "deviceId": alarm.device.id,
            "deviceName": alarm.device.name,
            "position": alarm.position,
            "weekdays": weekdayValues
        ]
        let description = (try? JSONSerialization.data(withJSONObject: metadata))
            .flatMap { String(data: $0, encoding: .utf8) } ?? ""

        // Use the label as the alias if provided, otherwise use the halarm ID
        let alias = alarm.label.isEmpty ? "halarm_\(automationId)" : alarm.label

        return HAAutomation(
            id: automationId,
            alias: alias,
            description: description,
            triggers: [trigger],  // Changed from "trigger"
            conditions: conditions,  // Changed from "condition"
            actions: [action],  // Changed from "action"
            mode: "single"
        )
    }

    nonisolated static func toAlarm(from automation: HAAutomation) -> Alarm? {
        // Since automations come from /api/halarm/automations endpoint,
        // they're already filtered to be halarm automations. Just verify the alias exists.
        guard automation.alias != nil else {
            return nil
        }

        // Extract time from trigger (new format)
        guard let trigger = automation.triggers?.first,
              trigger.trigger == "time",
              let timeStr = trigger.at else {
            return nil
        }

        let timeParts = timeStr.split(separator: ":")
        guard timeParts.count >= 2,
              let hour = Int(timeParts[0]),
              let minute = Int(timeParts[1]) else {
            return nil
        }

        // Extract device and position from action (new format)
        guard let action = automation.actions?.first,
              let target = action.target,
              let entityId = target.entity_id,
              let position = action.data?.position else {
            return nil
        }

        // Parse metadata from description (stored as JSON) early to get weekdays
        var label = automation.alias ?? ""
        var deviceId = entityId
        var deviceName: String? = nil
        var weekdays: Set<Weekday> = []
        var weekdaysFromMetadata = false

        if let description = automation.description,
           !description.isEmpty,
           let data = description.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let metadataLabel = json["label"] as? String {
                label = metadataLabel
            }
            if let metadataDeviceId = json["deviceId"] as? String {
                deviceId = metadataDeviceId
            }
            if let metadataDeviceName = json["deviceName"] as? String {
                deviceName = metadataDeviceName
            }
            // Check for weekdays in metadata (round-trip support)
            if let metadataWeekdays = json["weekdays"] as? [String] {
                weekdays = Set(metadataWeekdays.compactMap { Weekday(rawValue: $0) })
                weekdaysFromMetadata = true
            }
        }

        // If weekdays not found in metadata, extract from conditions (backward compatibility)
        if !weekdaysFromMetadata {
            if let condition = automation.conditions?.first,
               let weekdayStrings = condition.weekday {
                weekdays = Set(weekdayStrings.compactMap { Weekday(rawValue: $0) })
            }
            if weekdays.isEmpty {
                weekdays = Set(Weekday.allCases) // No condition = every day (backward compat)
            }
        }

        return Alarm(
            id: automation.id,
            label: label,
            hour: hour,
            minute: minute,
            weekdays: weekdays,
            isEnabled: true,  // HA 2026.2.2 doesn't use "enabled" field
            device: CoverEntity(id: deviceId, name: deviceName ?? deviceId),
            position: position
        )
    }
}
