import Foundation
import ImmichClient

public enum ConnectionError {
    public static func message(for error: ImmichError) -> String {
        switch error {
        case .unauthorized:
            String(localized: "Invalid API key.", bundle: .module)
        case .unreachable:
            String(localized: "Server not reachable.", bundle: .module)
        case .invalidResponse:
            String(localized: "Unexpected response from the server.", bundle: .module)
        }
    }
}
