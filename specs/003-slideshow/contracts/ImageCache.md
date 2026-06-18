# Contract: ImageCache

Größenbegrenzter In-Memory-Cache für Preview-Bilddaten. Hält den Speicher im Dauerbetrieb stabil
(FR-007/SC-004). Reiner Wertespeicher über `Data` je Asset-ID — kein UIKit, host-testbar.

## Signatur

```swift
public final class ImageCache: @unchecked Sendable {
    public init(limit: Int)

    public func data(for assetID: String) -> Data?   // markiert als zuletzt genutzt (LRU)
    public func store(_ data: Data, for assetID: String)
    public func contains(_ assetID: String) -> Bool
    public var count: Int { get }                     // nie > limit
}
```

## Verhalten

- `store(_:for:)`: legt Daten ab; überschreitet `count` danach `limit`, wird der am längsten nicht
  genutzte Eintrag verworfen, bis `count <= limit`.
- `data(for:)`: liefert Daten (falls vorhanden) und frischt deren LRU-Position auf.
- `contains(_:)`: ohne LRU-Effekt (reiner Lookup für Prefetch-Entscheidung).
- Thread-safe über internes Lock (`@unchecked Sendable`), analog zu den In-Memory-Stores im Projekt.

## Invarianten

- `count` ist nie größer als `limit` (SC-004).
- `limit >= 1`. Empfohlen `limit >= prefetchDepth + 1`, damit aktuelles + vorgeladene Bilder Platz
  haben (sonst würde Prefetch das aktuelle Bild verdrängen).

## Tests (TDD, Host)

- Store über `limit` hinaus → `count == limit`; der älteste (am längsten nicht genutzte) Eintrag ist
  weg, die jüngeren sind da.
- `data(for:)` auf einen Eintrag frischt ihn auf → bei nächster Eviction überlebt er, ein anderer
  fällt zuerst.
- `contains(_:)` ändert die LRU-Reihenfolge nicht.
