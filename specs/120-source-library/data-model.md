# Phase 1 Data Model — Source Library

Swift sketches are indicative (final names/signatures land via TDD). All value types are `Sendable`
and `Equatable`; `Codable` where persisted.

## Source

One saved slideshow source. Stable `id` (UUID string), user-facing `label`, and a `kind` carrying
its locator.

```swift
public struct Source: Codable, Sendable, Equatable, Identifiable {
    public let id: String          // stable local id (UUID)
    public var label: String       // unique within the library (D6/OQ2)
    public var kind: SourceKind
}

public enum SourceKind: Codable, Sendable, Equatable {
    case album(albumID: String)                 // served by AppConfiguration.baseURL + Keychain API key
    case sharedLink(baseURL: URL, slug: String) // password (if any) lives in the Keychain, keyed by Source.id
}
```

Validation:
- `label` non-empty and unique within the library (enforced by `SourceLibrary` ops + the UI).
- `album` requires a configured server + API key (the existing AppConfiguration).
- `sharedLink` requires a parseable `…/s/<slug>` URL → `baseURL` + `slug`.

## SourceLibrary

Ordered list of sources plus the active id. Pure value type with operations; no I/O.

```swift
public struct SourceLibrary: Codable, Sendable, Equatable {
    public private(set) var sources: [Source]
    public private(set) var activeID: String?

    public var active: Source? { sources.first { $0.id == activeID } }

    public mutating func add(_ source: Source)          // append; first add becomes active; label must be unique
    public mutating func remove(id: String)             // if active removed, promote the next (or nil if empty)
    public mutating func move(from: IndexSet, to: Int)   // reorder
    public mutating func rename(id: String, to: String)  // unique-label enforced
    public mutating func setActive(id: String)           // no-op if id unknown
}
```

State transitions:
- Empty → first `add` sets `activeID` to that source.
- `remove(active)` → promote the first remaining source, or `activeID = nil` when none remain (app
  falls back to onboarding/empty state).
- `setActive` only accepts a known id.

## Stores (protocols + concrete impls)

```swift
public protocol SourceLibraryStore: Sendable {
    func load() -> SourceLibrary          // performs one-time migration from selectedAlbumID
    func save(_ library: SourceLibrary)
    func clear()
}
```
- `UserDefaultsSourceLibraryStore`: JSON under `immich.sourceLibrary`. On `load()` with no library
  but a legacy `immich.selectedAlbumID`, synthesize + persist a one-entry album library (D4).
- In-memory fake for tests.

```swift
public protocol SharedLinkSecretStore: Sendable {
    func savePassword(_ password: String, forSourceID id: String) throws
    func readPassword(forSourceID id: String) -> String?
    func deletePassword(forSourceID id: String)
}
```
- Keychain-backed (account = source id, distinct service from the API key). In-memory fake for tests.
- Removing a `sharedLink` source deletes its password.

## ServerConfig auth mode (ImmichClient)

```swift
public struct ServerConfig: Sendable {
    public let baseURL: URL
    public let auth: Auth
    public enum Auth: Sendable { case apiKey(String); case shareKey(String) }
}
```
- `.apiKey` → `x-api-key` header (current behavior; keep a convenience init for source compat).
- `.shareKey` → append `key=<token>` query item to every request URL.

## SharedLinkResolver (ImmichClient)

```swift
public struct SharedLinkResolution: Sendable, Equatable {
    public let key: String        // bearer; never persisted, never logged
    public let albumID: String
    public let expiresAt: Date?
}

public protocol SharedLinkResolving: Sendable {
    func resolve(baseURL: URL, slug: String, password: String?) async throws -> SharedLinkResolution
}
```
- `GET /api/shared-links/me?slug=<slug>[&password=<pw>]`; maps errors per research D2.

## Errors (ImmichError additions)

```swift
// add to ImmichError
case invalidShareLink      // unknown/revoked slug
case shareLinkExpired      // past expiresAt / server-signalled expiry
case wrongPassword         // 401 with a password supplied
case passwordRequired      // 401 with no password supplied (protected link)
```
- `unreachable` / `unauthorized` (existing) cover transport and API-key failures.

## Active-source resolution (app composition)

`activeSource → (ServerConfig, albumID)`:
- `.album(albumID)` → `ServerConfig(baseURL: appConfig.baseURL, auth: .apiKey(keychainKey))`, album =
  `albumID`.
- `.sharedLink(baseURL, slug)` → resolve(slug, password?) → `ServerConfig(baseURL, auth:
  .shareKey(resolution.key))`, album = `resolution.albumID`.

The result feeds the existing `ImmichClient` + `SlideshowViewModel(api:albumID:…)` unchanged.
