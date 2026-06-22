# Contract: `BrokerSetupViewModel`

Package: `BrokerSetupKit`. NEW `@Observable` view model extracted from `BrokerSetupView` so the broker
form logic is host-testable and embeddable inline in the Settings disclosure section. Backs US2 (MQTT
fold-in). No behavior change versus the current view — only relocation + a test seam.

## Surface

```
@Observable final class BrokerSetupViewModel {
    var host: String
    var port: String            // numeric text; parsed on save
    var username: String
    var password: String        // secure; empty + existing ⇒ keep stored
    private(set) var passwordIsSet: Bool
    private(set) var validationMessage: String?

    init(store: any BrokerSettingsStore)

    func load()                 // prefill host/port/username; password stays blank; passwordIsSet = true
    func save() -> Bool         // true on success (caller dismisses/collapses), false on validation error
    func remove()               // clears the stored broker
}
```

Dependency injected via `BrokerSettingsStore` (existing protocol). Tests use an in-memory store.

## Behavior (verbatim from current `BrokerSetupView`)

- **`load()`**: if a broker is stored, set `host`/`port`(as string)/`username` from it, leave
  `password` empty, set `passwordIsSet = true`. The secret is never prefilled (FR-013).
- **`save()`**: if `password` is empty and a broker is stored, reuse the stored secret; build
  `BrokerSettings(host:, port: Int(port) ?? 0, username:, password:)`; call `store.save`. On
  `BrokerValidationError`, set `validationMessage` via the existing mapping and return `false`. On
  success clear `validationMessage` and return `true`.
- **`remove()`**: `store.clear()`.

## Acceptance tests (Swift Testing, host)

| Test | Given | Then |
|------|-------|------|
| `loadPrefillsWithoutSecret` | store has a broker | host/port/username filled, `password == ""`, `passwordIsSet == true` |
| `saveNewBrokerPersists` | valid fields, empty store | `store.load()` returns the broker, `save()` == true |
| `saveEmptyPasswordKeepsExisting` | broker stored, `password == ""` | saved broker keeps the previously stored secret |
| `saveInvalidPortReportsError` | `port = "0"` | `save()` == false, `validationMessage` set, store unchanged |
| `saveEmptyHostReportsError` | `host = ""` | `save()` == false, `validationMessage` set |
| `removeClearsStore` | broker stored | `store.load()` == nil after `remove()` |

## Notes

- The validation-message mapping (`BrokerValidationError → String`) moves with the logic; the existing
  `BrokerSettings.validate()` is unchanged.
- The SwiftUI section/host (`SlideshowSettingsView` disclosure content) and any standalone wrapper are
  verified via simulator/XcUITest, not in these host unit tests.
