import Foundation

public struct ImmichClient: ImmichAPI {
    private let config: ServerConfig
    private let transport: HTTPTransport

    public init(config: ServerConfig, transport: HTTPTransport = URLSessionTransport()) {
        self.config = config
        self.transport = transport
    }

    public func albums() async throws -> [Album] {
        let request = makeRequest(path: "api/albums")
        let (data, response) = try await transport.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw ImmichError.invalidResponse
        }

        return try JSONDecoder().decode([Album].self, from: data)
    }

    public func assets(albumID: String) async throws -> [Asset] {
        let request = makeRequest(path: "api/albums/\(albumID)")
        let (data, response) = try await transport.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw ImmichError.invalidResponse
        }

        return try JSONDecoder().decode(AlbumDetail.self, from: data).assets
    }

    public func preview(assetID: String) async throws -> Data {
        let request = makeRequest(
            path: "api/assets/\(assetID)/thumbnail",
            queryItems: [URLQueryItem(name: "size", value: "preview")]
        )
        let (data, response) = try await transport.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw ImmichError.invalidResponse
        }

        return data
    }

    private func makeRequest(path: String, queryItems: [URLQueryItem] = []) -> URLRequest {
        let url = config.baseURL.appending(path: path)
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.queryItems = queryItems.isEmpty ? nil : queryItems
        var request = URLRequest(url: url)
        if let componentURL = components?.url {
            request.url = componentURL
        }
        request.httpMethod = "GET"
        request.setValue(config.apiKey, forHTTPHeaderField: "x-api-key")
        return request
    }
}
