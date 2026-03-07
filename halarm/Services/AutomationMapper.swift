import Foundation

enum AutomationMapper {
    static func toHA(from alarm: Alarm) -> HAAutomation {
        let automationId = alarm.id.replacingOccurrences(of: "halarm_", with: "")

        let trigger = HATrigger(
            platform: "time",
            at: String(format: "%02d:%02d:00", alarm.hour, alarm.minute)
        )

        let weekdayValues = alarm.weekdays
            .sorted { $0.rawValue < $1.rawValue }
            .map { $0.rawValue }

        let condition = HACondition(
            condition: "time",
            weekday: weekdayValues.isEmpty ? nil : weekdayValues
        )

        let action = HAAction(
            service: "cover.set_cover_position",
            target: HATarget(entity_id: alarm.device.id),
            data: HAData(position: alarm.position)
        )

        return HAAutomation(
            id: automationId,
            alias: "halarm_\(automationId)",
            unique_id: "halarm_\(automationId)",
            trigger: [trigger],
            condition: alarm.weekdays.count == 7 ? nil : [condition],
            action: [action],
            enabled: alarm.isEnabled,
            mode: "single"
        )
    }

    static func toAlarm(from automation: HAAutomation) -> Alarm? {
        guard let alias = automation.alias, alias.hasPrefix("halarm_") else {
            return nil
        }

        // Extract time from trigger
        guard let trigger = automation.trigger?.first,
              trigger.platform == "time",
              let timeStr = trigger.at else {
            return nil
        }

        let timeParts = timeStr.split(separator: ":")
        guard timeParts.count >= 2,
              let hour = Int(timeParts[0]),
              let minute = Int(timeParts[1]) else {
            return nil
        }

        // Extract weekdays from condition
        var weekdays: Set<Weekday> = []
        if let condition = automation.condition?.first,
           let weekdayStrings = condition.weekday {
            weekdays = Set(weekdayStrings.compactMap { Weekday(rawValue: $0) })
        }
        if weekdays.isEmpty {
            weekdays = Set(Weekday.allCases) // No condition = every day
        }

        // Extract device and position from action
        guard let action = automation.action?.first,
              let target = action.target,
              let entityId = target.entity_id,
              let position = action.data?.position else {
            return nil
        }

        return Alarm(
            id: automation.id,
            label: alias,
            hour: hour,
            minute: minute,
            weekdays: weekdays,
            isEnabled: automation.enabled ?? true,
            device: CoverEntity(id: entityId, name: entityId),
            position: position
        )
    }
}
