import Foundation
import ImmichClient

public actor MockTransport: HTTPTransport {
    private let result: Result<(Data, URLResponse), Error>
    private var requests: [URLRequest] = []

    public var recordedRequests: [URLRequest] {
        requests
    }

    public init(result: Result<(Data, URLResponse), Error>) {
        self.result = result
    }

    public func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        requests.append(request)
        return try result.get()
    }
}
