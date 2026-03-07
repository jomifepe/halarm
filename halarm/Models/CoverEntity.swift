import Foundation

struct CoverEntity: Identifiable, Hashable, Codable {
    let id: String          // entity_id: "cover.bedroom_blind"
    let name: String        // friendly_name

    enum CodingKeys: String, CodingKey {
        case id = "entity_id"
        case name = "friendly_name"
    }
}
