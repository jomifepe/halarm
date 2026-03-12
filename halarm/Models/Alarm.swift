import Foundation

struct Alarm: Identifiable, Hashable, Codable {
    let id: String              // HA automation ID (unique_id)
    var label: String
    var hour: Int               // 0-23
    var minute: Int             // 0-59
    var weekdays: Set<Weekday>
    var isEnabled: Bool
    var device: CoverEntity
    var position: Int           // 0-100

    var timeString: String {
        String(format: "%02d:%02d", hour, minute)
    }

    var weekdayString: String {
        let sorted = weekdays.sorted { $0.rawValue < $1.rawValue }
        guard !sorted.isEmpty else { return "None" }
        if sorted.count == 7 {
            return "Every day"
        }
        let workdays: Set<Weekday> = [.mon, .tue, .wed, .thu, .fri]
        if Set(sorted) == workdays {
            return "Weekdays"
        }
        return sorted.map { $0.displayName }.joined(separator: ", ")
    }
}
