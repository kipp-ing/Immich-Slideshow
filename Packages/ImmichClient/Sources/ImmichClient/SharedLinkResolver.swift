import Foundation

public struct SharedLinkResolution: Sendable, Equatable {
    public let key: String
    public let albumID: String
    public let expiresAt: Date?

    public init(key: String, albumID: String, expiresAt: Date?) {
        self.key = key
        self.albumID = albumID
        self.expiresAt = expiresAt
    }
}

public protocol SharedLinkResolving: Sendable {
    func resolve(baseURL: URL, slug: String, password: String?) async throws -> SharedLinkResolution
}

public struct SharedLinkResolver: SharedLinkResolving {
    private let transport: HTTPTransport
    private let now: @Sendable () -> Date

    public init(transport: HTTPTransport = URLSessionTransport(), now: @escaping @Sendable () -> Date = Date.init) {
        self.transport = transport
        self.now = now
    }

    public func resolve(baseURL: URL, slug: String, password: String?) async throws -> SharedLinkResolution {
        let request = makeRequest(baseURL: baseURL, slug: slug, password: password)

        do {
            let (data, response) = try await transport.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ImmichError.invalidResponse
            }

            switch httpResponse.statusCode {
            case 200..<300:
                let resolution = try decodeResolution(from: data)
                if let expiresAt = resolution.expiresAt, expiresAt <= now() {
                    throw ImmichError.shareLinkExpired
                }
                return resolution
            case 401:
                throw password == nil ? ImmichError.passwordRequired : ImmichError.wrongPassword
            case 404:
                throw ImmichError.invalidShareLink
            case 410:
                throw ImmichError.shareLinkExpired
            default:
                throw ImmichError.invalidResponse
            }
        } catch let error as ImmichError {
            throw error
        } catch is URLError {
            throw ImmichError.unreachable
        }
    }

    private func makeRequest(baseURL: URL, slug: String, password: String?) -> URLRequest {
        let url = baseURL.appending(path: "api/shared-links/me")
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        var queryItems = [URLQueryItem(name: "slug", value: slug)]
        if let password {
            queryItems.append(URLQueryItem(name: "password", value: password))
        }
        components?.queryItems = queryItems

        var request = URLRequest(url: url)
        if let componentURL = components?.url {
            request.url = componentURL
        }
        request.httpMethod = "GET"
        return request
    }

    private func decodeResolution(from data: Data) throws -> SharedLinkResolution {
        do {
            let response = try JSONDecoder().decode(SharedLinkMeResponse.self, from: data)
            return SharedLinkResolution(
                key: response.key,
                albumID: response.album.id,
                expiresAt: response.expiresAt.flatMap(parseISO8601Date)
            )
        } catch let error as ImmichError {
            throw error
        } catch {
            throw ImmichError.invalidResponse
        }
    }

    private func parseISO8601Date(_ string: String) -> Date? {
        let fractionalFormatter = ISO8601DateFormatter()
        fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractionalFormatter.date(from: string) {
            return date
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string)
    }
}

private struct SharedLinkMeResponse: Decodable {
    let key: String
    let album: AlbumReference
    let expiresAt: String?

    struct AlbumReference: Decodable {
        let id: String
    }
}
