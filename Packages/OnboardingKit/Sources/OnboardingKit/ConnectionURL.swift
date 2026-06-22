import Foundation

public enum ConnectionURL {
    public static func normalize(_ raw: String) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let urlString = trimmed.contains("://") ? trimmed : "https://\(trimmed)"
        guard
            let url = URL(string: urlString),
            url.scheme == "https",
            url.host != nil
        else {
            return nil
        }

        return url
    }
}
