import Foundation

public struct SourceLibrary: Codable, Sendable, Equatable {
    public private(set) var sources: [Source]
    public private(set) var activeID: String?

    public var active: Source? {
        sources.first { $0.id == activeID }
    }

    public init(sources: [Source] = [], activeID: String? = nil) {
        var uniqueSources: [Source] = []
        for source in sources where Self.isValidLabel(source.label) && !uniqueSources.contains(where: { $0.label == source.label }) {
            uniqueSources.append(source)
        }

        self.sources = uniqueSources
        self.activeID = uniqueSources.contains(where: { $0.id == activeID }) ? activeID : uniqueSources.first?.id
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let sources = try container.decode([Source].self, forKey: .sources)
        let activeID = try container.decodeIfPresent(String.self, forKey: .activeID)
        self.init(sources: sources, activeID: activeID)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(sources, forKey: .sources)
        try container.encodeIfPresent(activeID, forKey: .activeID)
    }

    public mutating func add(_ source: Source) {
        guard Self.isValidLabel(source.label), !sources.contains(where: { $0.label == source.label }) else {
            return
        }

        sources.append(source)
        if activeID == nil {
            activeID = source.id
        }
    }

    public mutating func remove(id: String) {
        guard let removedIndex = sources.firstIndex(where: { $0.id == id }) else {
            return
        }

        let wasActive = activeID == id
        sources.remove(at: removedIndex)

        if wasActive {
            activeID = sources.indices.contains(removedIndex) ? sources[removedIndex].id : sources.first?.id
        }
    }

    public mutating func move(from source: IndexSet, to destination: Int) {
        let indexes = source.sorted().filter { sources.indices.contains($0) }
        guard !indexes.isEmpty else {
            return
        }

        let movingSources = indexes.map { sources[$0] }
        for index in indexes.reversed() {
            sources.remove(at: index)
        }

        let removedBeforeDestination = indexes.filter { $0 < destination }.count
        let adjustedDestination = min(
            max(destination - removedBeforeDestination, sources.startIndex),
            sources.endIndex
        )
        sources.insert(contentsOf: movingSources, at: adjustedDestination)
    }

    public mutating func rename(id: String, to label: String) {
        guard
            Self.isValidLabel(label),
            let index = sources.firstIndex(where: { $0.id == id }),
            !sources.contains(where: { $0.id != id && $0.label == label })
        else {
            return
        }

        sources[index].label = label
    }

    public mutating func setActive(id: String) {
        guard sources.contains(where: { $0.id == id }) else {
            return
        }

        activeID = id
    }

    private static func isValidLabel(_ label: String) -> Bool {
        !label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private enum CodingKeys: String, CodingKey {
        case sources
        case activeID
    }
}
