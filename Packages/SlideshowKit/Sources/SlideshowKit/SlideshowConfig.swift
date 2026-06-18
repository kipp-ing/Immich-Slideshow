import Foundation

/// Feste v1-Parameter der Diashow. Keine UI-Konfiguration — Anzeigedauer/Effekte sind Sache des
/// späteren ThemeSettings-Moduls (FR-013).
public struct SlideshowConfig: Sendable, Equatable {
    /// Anzeigedauer pro Bild.
    public var interval: Duration
    /// Wie viele Bilder voraus vorgeladen werden (1–2).
    public var prefetchDepth: Int
    /// Maximale Zahl gleichzeitig im Cache gehaltener Bilder.
    public var cacheLimit: Int

    public init(interval: Duration, prefetchDepth: Int, cacheLimit: Int) {
        precondition(prefetchDepth >= 1, "prefetchDepth must be >= 1")
        precondition(cacheLimit >= prefetchDepth + 1, "cacheLimit must be >= prefetchDepth + 1")
        self.interval = interval
        self.prefetchDepth = prefetchDepth
        self.cacheLimit = cacheLimit
    }

    /// Gepinnte v1-Defaults (data-model.md).
    public static let `default` = SlideshowConfig(
        interval: .seconds(8),
        prefetchDepth: 2,
        cacheLimit: 5
    )
}
