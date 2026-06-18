import Foundation
import Testing
@testable import ImmichClient
import ImmichClientTestSupport

@Test func albumDetailJSONDecodesAssets() throws {
    let json = """
    {
        "assets": [
            {
                "id": "asset-1",
                "type": "IMAGE"
            },
            {
                "id": "asset-2",
                "type": "VIDEO"
            }
        ]
    }
    """
    let data = try #require(json.data(using: .utf8))

    let albumDetail = try JSONDecoder().decode(AlbumDetail.self, from: data)

    #expect(albumDetail.assets.count == 2)
    #expect(albumDetail.assets[0].id == "asset-1")
    #expect(albumDetail.assets[0].type == "IMAGE")
    #expect(albumDetail.assets[1].id == "asset-2")
    #expect(albumDetail.assets[1].type == "VIDEO")
}

@Test func assetsSendsGetRequestWithAPIKeyHeaderAndReturnsDecodedAssets() async throws {
    let baseURL = try #require(URL(string: "https://photos.example.test"))
    let requestURL = try #require(URL(string: "https://photos.example.test/api/albums/album-1"))
    let responseData = try #require("""
    {
        "assets": [
            {
                "id": "asset-1",
                "type": "IMAGE"
            },
            {
                "id": "asset-2",
                "type": "VIDEO"
            }
        ]
    }
    """.data(using: .utf8))
    let response = try #require(HTTPURLResponse(
        url: requestURL,
        statusCode: 200,
        httpVersion: nil,
        headerFields: nil
    ))
    let transport = MockTransport(result: .success((responseData, response)))
    let config = ServerConfig(baseURL: baseURL, apiKey: "secret-api-key")
    let client = ImmichClient(config: config, transport: transport)

    let assets = try await client.assets(albumID: "album-1")

    #expect(assets.count == 2)
    #expect(assets[0].id == "asset-1")
    #expect(assets[0].type == "IMAGE")
    #expect(assets[1].id == "asset-2")
    #expect(assets[1].type == "VIDEO")

    let requests = await transport.recordedRequests
    let request = try #require(requests.only)
    #expect(request.httpMethod == "GET")
    #expect(request.url?.path == "/api/albums/album-1")
    #expect(request.url?.path.contains("album-1") == true)
    #expect(request.value(forHTTPHeaderField: "x-api-key") == config.apiKey)
}

@Test func assetsReturnsEmptyArrayForAlbumWithoutAssets() async throws {
    let baseURL = try #require(URL(string: "https://photos.example.test"))
    let requestURL = try #require(URL(string: "https://photos.example.test/api/albums/empty-album"))
    let responseData = try #require(#"{"assets":[]}"#.data(using: .utf8))
    let response = try #require(HTTPURLResponse(
        url: requestURL,
        statusCode: 200,
        httpVersion: nil,
        headerFields: nil
    ))
    let transport = MockTransport(result: .success((responseData, response)))
    let config = ServerConfig(baseURL: baseURL, apiKey: "secret-api-key")
    let client = ImmichClient(config: config, transport: transport)

    let assets = try await client.assets(albumID: "empty-album")

    #expect(assets.isEmpty)
}

private extension Array {
    var only: Element? {
        count == 1 ? self[0] : nil
    }
}
