import Foundation

public final class ImageCache: @unchecked Sendable {
    private let limit: Int
    private let lock = NSLock()
    private var storage: [String: Data] = [:]
    private var leastToMostRecent: [String] = []

    public init(limit: Int) {
        precondition(limit >= 1, "limit must be >= 1")
        self.limit = limit
    }

    public func data(for assetID: String) -> Data? {
        lock.withLock {
            guard let data = storage[assetID] else {
                return nil
            }

            markRecentlyUsed(assetID)
            return data
        }
    }

    public func store(_ data: Data, for assetID: String) {
        lock.withLock {
            storage[assetID] = data
            markRecentlyUsed(assetID)

            while storage.count > limit, let evicted = leastToMostRecent.first {
                leastToMostRecent.removeFirst()
                storage[evicted] = nil
            }
        }
    }

    public func contains(_ assetID: String) -> Bool {
        lock.withLock {
            storage[assetID] != nil
        }
    }

    public var count: Int {
        lock.withLock {
            storage.count
        }
    }

    private func markRecentlyUsed(_ assetID: String) {
        leastToMostRecent.removeAll { $0 == assetID }
        leastToMostRecent.append(assetID)
    }
}

extension NSLock {
    @discardableResult
    fileprivate func withLock<T>(_ body: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try body()
    }
}
