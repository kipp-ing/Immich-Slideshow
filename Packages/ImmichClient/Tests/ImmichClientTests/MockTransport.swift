import Foundation
@testable import ImmichClient

actor MockTransport: HTTPTransport {
    private let result: Result<(Data, URLResponse), Error>
    private var requests: [URLRequest] = []

    var recordedRequests: [URLRequest] {
        requests
    }

    init(result: Result<(Data, URLResponse), Error>) {
        self.result = result
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        requests.append(request)
        return try result.get()
    }
}
