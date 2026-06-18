import Foundation
import Testing
@testable import ImmichClient
import ImmichClientTestSupport

@Test func serverVersionReturnsVersionStringAndSendsGetRequest() async throws {
    let baseURL = try #require(URL(string: "https://photos.example.test"))
    let requestURL = try #require(URL(string: "https://photos.example.test/api/server/version"))
    let responseData = try #require(#"{"major":1,"minor":119,"patch":0}"#.data(using: .utf8))
    let response = try #require(HTTPURLResponse(
        url: requestURL,
        statusCode: 200,
        httpVersion: nil,
        headerFields: nil
    ))
    let transport = MockTransport(result: .success((responseData, response)))
    let config = ServerConfig(baseURL: baseURL, apiKey: "secret-api-key")
    let client = ImmichClient(config: config, transport: transport)

    let version = try await client.serverVersion()

    #expect(!version.isEmpty)
    let requests = await transport.recordedRequests
    let request = try #require(requests.only)
    #expect(request.url?.path == "/api/server/version")
    #expect(request.httpMethod == "GET")
}

@Test func serverVersionMapsURLErrorToUnreachable() async throws {
    let baseURL = try #require(URL(string: "https://photos.example.test"))
    let transport = MockTransport(result: .failure(URLError(.timedOut)))
    let config = ServerConfig(baseURL: baseURL, apiKey: "secret-api-key")
    let client = ImmichClient(config: config, transport: transport)

    await #expect(throws: ImmichError.unreachable) {
        _ = try await client.serverVersion()
    }
}

@Test func serverVersionMapsInvalidResponseToInvalidResponse() async throws {
    let baseURL = try #require(URL(string: "https://photos.example.test"))
    let requestURL = try #require(URL(string: "https://photos.example.test/api/server/version"))
    let responseData = Data("{}".utf8)
    let response = try #require(HTTPURLResponse(
        url: requestURL,
        statusCode: 500,
        httpVersion: nil,
        headerFields: nil
    ))
    let transport = MockTransport(result: .success((responseData, response)))
    let config = ServerConfig(baseURL: baseURL, apiKey: "secret-api-key")
    let client = ImmichClient(config: config, transport: transport)

    await #expect(throws: ImmichError.invalidResponse) {
        _ = try await client.serverVersion()
    }
}

private extension Array {
    var only: Element? {
        count == 1 ? self[0] : nil
    }
}
