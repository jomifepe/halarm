import Foundation

enum Weekday: String, CaseIterable, Codable, Hashable {
    case mon = "mon"
    case tue = "tue"
    case wed = "wed"
    case thu = "thu"
    case fri = "fri"
    case sat = "sat"
    case sun = "sun"

    var displayName: String {
        switch self {
        case .mon: "Mon"
        case .tue: "Tue"
        case .wed: "Wed"
        case .thu: "Thu"
        case .fri: "Fri"
        case .sat: "Sat"
        case .sun: "Sun"
        }
    }
}
