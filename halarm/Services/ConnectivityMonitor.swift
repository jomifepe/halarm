import Foundation
import Network

@MainActor
@Observable
final class ConnectivityMonitor {
    static let shared = ConnectivityMonitor()

    private let monitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "halarm.connectivity-monitor")

    private(set) var isNetworkAvailable = true
    private(set) var isHomeAssistantReachable = true

    var isOffline: Bool {
        !isNetworkAvailable || !isHomeAssistantReachable
    }

    var statusMessage: String? {
        guard isOffline else { return nil }

        if !isNetworkAvailable {
            return "No network connection. Showing your last synced data."
        }

        return "Home Assistant is unreachable. Showing your last synced data."
    }

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.isNetworkAvailable = path.status == .satisfied
            }
        }
        monitor.start(queue: monitorQueue)
    }

    deinit {
        monitor.cancel()
    }

    func reportRequestSuccess() {
        isHomeAssistantReachable = true
    }

    func reportRequestFailure(_ error: Error) {
        guard Self.isReachabilityError(error) else { return }
        isHomeAssistantReachable = false
    }

    private static func isReachabilityError(_ error: Error) -> Bool {
        guard let urlError = error as? URLError else { return false }

        switch urlError.code {
        case .timedOut,
             .cannotFindHost,
             .cannotConnectToHost,
             .networkConnectionLost,
             .dnsLookupFailed,
             .notConnectedToInternet,
             .internationalRoamingOff,
             .callIsActive,
             .dataNotAllowed,
             .secureConnectionFailed,
             .cannotLoadFromNetwork:
            return true
        default:
            return false
        }
    }
}
