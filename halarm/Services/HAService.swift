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
        // Try the newer API endpoint first
        let endpoints = [
            "/api/automation",
            "/api/automations",
            "/api/config/automation/config"
        ]

        var lastError: HAError = HAError.httpError(404)

        for endpoint in endpoints {
            let url = URL(string: baseURL + endpoint)!
            var request = URLRequest(url: url)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

            do {
                let (data, response) = try await session.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw HAError.invalidResponse
                }

                if httpResponse.statusCode == 200 {
                    let automations = try JSONDecoder().decode([HAAutomation].self, from: data)
                    return automations
                        .filter { $0.alias?.hasPrefix("halarm_") ?? false }
                        .compactMap { automation in
                            AutomationMapper.toAlarm(from: automation)
                        }
                }
                lastError = HAError.httpError(httpResponse.statusCode)
            } catch {
                lastError = HAError.decodingError
                continue
            }
        }

        throw lastError
    }

    func createAlarm(_ alarm: Alarm) async throws -> Alarm {
        let url = URL(string: baseURL + "/api/config/automation/config")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let automation = AutomationMapper.toHA(from: alarm)
        request.httpBody = try JSONEncoder().encode(automation)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, (200...201).contains(httpResponse.statusCode) else {
            throw HAError.httpError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }

        let created = try JSONDecoder().decode(HAAutomation.self, from: data)
        guard let mapped = AutomationMapper.toAlarm(from: created) else {
            throw HAError.decodingError
        }
        return mapped
    }

    func updateAlarm(_ alarm: Alarm) async throws {
        let url = URL(string: baseURL + "/api/config/automation/config/\(alarm.id)")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpMethod = "PUT"
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

    func setEnabled(id: String, enabled: Bool) async throws {
        let service = enabled ? "turn_on" : "turn_off"
        let url = URL(string: baseURL + "/api/services/automation/\(service)")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload = ["entity_id": "automation.\(id)"]
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
    let unique_id: String?
    let trigger: [HATrigger]?
    let condition: [HACondition]?
    let action: [HAAction]?
    let enabled: Bool?
    let mode: String?
}

struct HATrigger: Codable {
    let platform: String
    let at: String?
}

struct HACondition: Codable {
    let condition: String
    let weekday: [String]?
}

struct HAAction: Codable {
    let service: String
    let target: HATarget?
    let data: HAData?
}

struct HATarget: Codable {
    let entity_id: String?
}

struct HAData: Codable {
    let position: Int?
}

// MARK: - Errors

enum HAError: LocalizedError {
    case invalidResponse
    case unauthorized
    case httpError(Int)
    case decodingError
    case networkError(Error)

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
        }
    }
}
