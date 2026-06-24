import Foundation
import Testing
@testable import ImmichClient
import ImmichClientTestSupport

@Test func resolverRequestsSharedLinkMeWithSlugAndPasswordAndReturnsResolution() async throws {
    let baseURL = try #require(URL(string: "https://photos.example.test"))
    let responseData = try #require("""
    {
        "key": "shared-bearer-key",
        "album": {
            "id": "album-1"
        },
        "expiresAt": "2026-07-01T12:00:00.000Z"
    }
    """.data(using: .utf8))
    let transport = MockTransport(result: .success((responseData, httpResponse(url: baseURL, statusCode: 200))))
    let resolver = SharedLinkResolver(transport: transport)

    let resolution = try await resolver.resolve(baseURL: baseURL, slug: "summer", password: "secret-password")

    #expect(resolution.key == "shared-bearer-key")
    #expect(resolution.albumID == "album-1")
    #expect(resolution.expiresAt == isoDate("2026-07-01T12:00:00.000Z"))

    let request = try await #require(transport.recordedRequests.only)
    #expect(request.httpMethod == "GET")
    #expect(request.url?.path == "/api/shared-links/me")
    #expect(queryValue("slug", in: request.url) == "summer")
    #expect(queryValue("password", in: request.url) == "secret-password")
    #expect(request.value(forHTTPHeaderField: "x-api-key") == nil)
}

@Test func resolverMapsMissingPasswordUnauthorizedToPasswordRequired() async throws {
    try await expectResolverError(statusCode: 401, password: nil, expectedError: .passwordRequired)
}

@Test func resolverMapsWrongPasswordUnauthorizedToWrongPassword() async throws {
    try await expectResolverError(statusCode: 401, password: "wrong", expectedError: .wrongPassword)
}

@Test func resolverMapsNotFoundToInvalidShareLink() async throws {
    try await expectResolverError(statusCode: 404, password: nil, expectedError: .invalidShareLink)
}

@Test func resolverMapsServerSignalledExpiryToShareLinkExpired() async throws {
    try await expectResolverError(statusCode: 410, password: nil, expectedError: .shareLinkExpired)
}

@Test func resolverMapsPastExpiresAtToShareLinkExpired() async throws {
    let baseURL = try #require(URL(string: "https://photos.example.test"))
    let responseData = try #require("""
    {
        "key": "shared-bearer-key",
        "album": {
            "id": "album-1"
        },
        "expiresAt": "2000-01-01T00:00:00.000Z"
    }
    """.data(using: .utf8))
    let transport = MockTransport(result: .success((responseData, httpResponse(url: baseURL, statusCode: 200))))
    let resolver = SharedLinkResolver(transport: transport)

    await #expect(throws: ImmichError.shareLinkExpired) {
        _ = try await resolver.resolve(baseURL: baseURL, slug: "expired", password: nil)
    }
}

@Test func resolverMapsTransportFailureToUnreachable() async throws {
    let baseURL = try #require(URL(string: "https://photos.example.test"))
    let transport = MockTransport(result: .failure(URLError(.timedOut)))
    let resolver = SharedLinkResolver(transport: transport)

    await #expect(throws: ImmichError.unreachable) {
        _ = try await resolver.resolve(baseURL: baseURL, slug: "summer", password: nil)
    }
}

private func expectResolverError(
    statusCode: Int,
    password: String?,
    expectedError: ImmichError
) async throws {
    let baseURL = try #require(URL(string: "https://photos.example.test"))
    let transport = MockTransport(result: .success((Data(), httpResponse(url: baseURL, statusCode: statusCode))))
    let resolver = SharedLinkResolver(transport: transport)

    await #expect(throws: expectedError) {
        _ = try await resolver.resolve(baseURL: baseURL, slug: "summer", password: password)
    }
}

private func httpResponse(url: URL, statusCode: Int) -> HTTPURLResponse {
    HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
}

private func queryValue(_ name: String, in url: URL?) -> String? {
    guard let url else { return nil }
    return URLComponents(url: url, resolvingAgainstBaseURL: false)?
        .queryItems?
        .first { $0.name == name }?
        .value
}

private func isoDate(_ string: String) -> Date? {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter.date(from: string)
}

private extension Array {
    var only: Element? {
        count == 1 ? self[0] : nil
    }
}
