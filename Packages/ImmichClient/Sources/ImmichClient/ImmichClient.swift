import Foundation

public struct ImmichClient: ImmichAPI {
    private let config: ServerConfig
    private let transport: HTTPTransport

    public init(config: ServerConfig, transport: HTTPTransport = URLSessionTransport()) {
        self.config = config
        self.transport = transport
    }

    public func serverVersion() async throws -> String {
        let request = makeRequest(path: "api/server/version")
        let data = try await responseData(for: request)
        let version = try decode(ServerVersion.self, from: data)
        return "\(version.major).\(version.minor).\(version.patch)"
    }

    public func albums() async throws -> [Album] {
        let request = makeRequest(path: "api/albums")
        let data = try await responseData(for: request)
        return try decode([Album].self, from: data)
    }

    public func assets(albumID: String) async throws -> [Asset] {
        let request = makeRequest(path: "api/albums/\(albumID)")
        let data = try await responseData(for: request)
        return try decode(AlbumDetail.self, from: data).assets
    }

    public func preview(assetID: String) async throws -> Data {
        let request = makeRequest(
            path: "api/assets/\(assetID)/thumbnail",
            queryItems: [URLQueryItem(name: "size", value: "preview")]
        )
        return try await responseData(for: request)
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

    private func responseData(for request: URLRequest) async throws -> Data {
        do {
            let (data, response) = try await transport.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ImmichError.invalidResponse
            }

            switch httpResponse.statusCode {
            case 200..<300:
                return data
            case 401:
                throw ImmichError.unauthorized
            default:
                throw ImmichError.invalidResponse
            }
        } catch let error as ImmichError {
            throw error
        } catch is URLError {
            throw ImmichError.unreachable
        }
    }

    private func decode<Value: Decodable>(_ type: Value.Type, from data: Data) throws -> Value {
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch let error as ImmichError {
            throw error
        } catch {
            throw ImmichError.invalidResponse
        }
    }
}

private struct ServerVersion: Decodable {
    let major: Int
    let minor: Int
    let patch: Int
}
