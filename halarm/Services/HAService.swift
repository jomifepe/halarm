import Foundation

actor HAService {
    private let baseURL: String
    private let token: String
    private let session: URLSession

    init(baseURL: String, token: String) {
        self.baseURL = baseURL.trimmingCharacters(in: .whitespaces)
        self.token = token.trimmingCharacters(in: .whitespaces)

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        self.session = URLSession(configuration: config)
    }

    // MARK: - Connection Test

    func testConnection() async throws {
        let url = URL(string: baseURL + "/api/")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw HAError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200:
            return
        case 401:
            throw HAError.unauthorized
        default:
            throw HAError.httpError(httpResponse.statusCode)
        }
    }

    // MARK: - Entities

    func fetchCoverEntities() async throws -> [CoverEntity] {
        let url = URL(string: baseURL + "/api/states")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw HAError.httpError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }

        let states = try JSONDecoder().decode([HAState].self, from: data)
        return states
            .filter { $0.entity_id.hasPrefix("cover.") }
            .map { CoverEntity(id: $0.entity_id, name: $0.attributes.friendly_name ?? $0.entity_id) }
            .sorted { $0.name < $1.name }
    }

    // MARK: - Alarms (HA Automations)

    func fetchAlarms() async throws -> [Alarm] {
        // Fetch all halarm automations from the custom HA integration endpoint
        let url = URL(string: baseURL + "/api/halarm/automations")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw HAError.invalidResponse
        }

        if httpResponse.statusCode == 404 {
            throw HAError.pluginNotInstalled
        }

        guard httpResponse.statusCode == 200 else {
            throw HAError.httpError(httpResponse.statusCode)
        }

        let automations = try JSONDecoder().decode([HAAutomation].self, from: data)
        return automations
            .compactMap { AutomationMapper.toAlarm(from: $0) }
            .sorted { $0.label < $1.label }
    }

    func createAlarm(_ alarm: Alarm) async throws -> Alarm {
        // URL must include the automation ID in the path
        let url = URL(string: baseURL + "/api/config/automation/config/\(alarm.id)")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let automation = AutomationMapper.toHA(from: alarm)
        request.httpBody = try JSONEncoder().encode(automation)

        let (_, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, (200...201).contains(httpResponse.statusCode) else {
            throw HAError.httpError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }

        // Home Assistant doesn't return the created automation in the response,
        // so we just return the alarm we created
        return alarm
    }

    func updateAlarm(_ alarm: Alarm) async throws {
        let url = URL(string: baseURL + "/api/config/automation/config/\(alarm.id)")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let automation = AutomationMapper.toHA(from: alarm)
        request.httpBody = try JSONEncoder().encode(automation)

        let (_, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, (200...204).contains(httpResponse.statusCode) else {
            throw HAError.httpError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }
    }

    func deleteAlarm(id: String) async throws {
        let url = URL(string: baseURL + "/api/config/automation/config/\(id)")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpMethod = "DELETE"

        let (_, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, (200...204).contains(httpResponse.statusCode) else {
            throw HAError.httpError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }
    }

    func setEnabled(id: String, label: String, enabled: Bool) async throws {
        let service = enabled ? "turn_on" : "turn_off"
        let url = URL(string: baseURL + "/api/services/automation/\(service)")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Construct entity_id from label (convert to lowercase, replace spaces with underscores)
        let entityId = "automation." + label.lowercased().replacingOccurrences(of: " ", with: "_")
        let payload = ["entity_id": entityId]
        request.httpBody = try JSONEncoder().encode(payload)

        let (_, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, (200...201).contains(httpResponse.statusCode) else {
            throw HAError.httpError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }
    }
}

// MARK: - HA API Response Models

struct HAState: Codable {
    let entity_id: String
    let state: String
    let attributes: HAAttributes
}

struct HAAttributes: Codable {
    let friendly_name: String?
}

struct HAAutomation: Codable {
    let id: String
    let alias: String?
    let description: String?
    let triggers: [HATrigger]?
    let conditions: [HACondition]?
    let actions: [HAAction]?
    let mode: String?

    enum CodingKeys: String, CodingKey {
        case id, alias, description, triggers, conditions, actions, mode
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(alias, forKey: .alias)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encodeIfPresent(triggers, forKey: .triggers)
        try container.encodeIfPresent(conditions, forKey: .conditions)
        try container.encodeIfPresent(actions, forKey: .actions)
        try container.encodeIfPresent(mode, forKey: .mode)
    }
}

struct HATrigger: Codable {
    let trigger: String  // "time", "state", etc.
    let at: String?      // time in HH:MM:SS format

    // For flexible decoding of additional fields
    var dynamicFields: [String: AnyCodable] = [:]

    enum CodingKeys: String, CodingKey {
        case trigger, at
    }
}

struct HACondition: Codable {
    let condition: String?
    let weekday: [String]?
}

struct HAAction: Codable {
    let action: String   // e.g., "cover.set_cover_position"
    let target: HATarget?
    let data: HAData?
}

struct HATarget: Codable {
    let entity_id: String?
}

struct HAData: Codable {
    let position: Int?
}

// Helper for decoding unknown fields
struct AnyCodable: Codable {
    let value: Any

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intVal = try? container.decode(Int.self) {
            value = intVal
        } else if let stringVal = try? container.decode(String.self) {
            value = stringVal
        } else if let boolVal = try? container.decode(Bool.self) {
            value = boolVal
        } else {
            value = NSNull()
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let intVal = value as? Int {
            try container.encode(intVal)
        } else if let stringVal = value as? String {
            try container.encode(stringVal)
        } else if let boolVal = value as? Bool {
            try container.encode(boolVal)
        }
    }
}

// MARK: - Errors

enum HAError: LocalizedError {
    case invalidResponse
    case unauthorized
    case httpError(Int)
    case decodingError
    case networkError(Error)
    case pluginNotInstalled

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from Home Assistant"
        case .unauthorized:
            return "Invalid token or unauthorized access"
        case .httpError(let code):
            return "HTTP error \(code)"
        case .decodingError:
            return "Failed to decode response"
        case .networkError(let error):
            return error.localizedDescription
        case .pluginNotInstalled:
            return "HAlarm plugin not installed. Copy ha_integration/custom_components/halarm/ to your HA config directory and add 'halarm:' to configuration.yaml, then restart HA."
        }
    }
}
