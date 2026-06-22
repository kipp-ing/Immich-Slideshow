# Contract: ImmichAPI.original (ImmichClient)

Adds full-resolution fetch to back the Original quality option. Extends the existing `ImmichAPI`
protocol; does not change `preview`/`thumbnail`.

## Protocol addition (conceptual)

```
protocol ImmichAPI {
    // existing: serverVersion, albums, assets, assetInfo, preview, thumbnail
    func original(assetID: String) async throws -> Data
}

extension ImmichAPI {
    // default fallback so existing mocks/stubs keep compiling/behaving
    func original(assetID: String) async throws -> Data { try await preview(assetID: assetID) }
}
```

## Behavioral contract

| # | Given | When | Then |
|---|-------|------|------|
| 1 | a valid asset ID | `original(assetID:)` on `ImmichClient` | issues `GET api/assets/{id}/original` with the `x-api-key` header (no TLS bypass) — FR-009, Constitution III/IV |
| 2 | a mock conforming to `ImmichAPI` without overriding `original` | `original(assetID:)` | returns the same data as `preview` (default impl) |
| 3 | a non-2xx / unreachable response | `original(assetID:)` | surfaces the same typed `ImmichError` as other fetches |

## Verification note (Constitution: API paths)

Confirm `assets/{id}/original` against the running server's OpenAPI (`/api/server/version`) at
implementation time; if the version differs, change only the path string in `ImmichClient`. The view
model selects `original` vs `preview` purely from `ThemeSettings.quality`.
