import Foundation

/// Parses a pasted Immich share URL (`https://<host>/s/<slug>`) into the non-secret
/// `baseURL` + `slug` stored on a `.sharedLink` source. Mirrors `ConnectionURL`:
/// HTTPS only, an `https://` scheme is assumed when the user omits it.
public enum SharedLinkURL {
    public static func parse(_ raw: String) -> (baseURL: URL, slug: String)? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let urlString = trimmed.contains("://") ? trimmed : "https://\(trimmed)"
        guard
            let url = URL(string: urlString),
            url.scheme == "https",
            let host = url.host,
            !host.isEmpty,
            let slug = slug(from: url.pathComponents)
        else {
            return nil
        }

        var base = URLComponents()
        base.scheme = "https"
        base.host = host
        base.port = url.port
        guard let baseURL = base.url else { return nil }

        return (baseURL, slug)
    }

    /// The slug is the segment after `/s/`; fall back to the last non-empty path
    /// segment so a `/share/<slug>` or bare-slug variant still resolves.
    private static func slug(from pathComponents: [String]) -> String? {
        let segments = pathComponents.filter { $0 != "/" && !$0.isEmpty }
        if let sIndex = segments.firstIndex(of: "s") {
            // An `/s/` marker with nothing after it is a malformed share URL.
            guard sIndex + 1 < segments.count else { return nil }
            return segments[sIndex + 1]
        }
        return segments.last
    }
}
