# Contract: OnboardingViewModel & StartupGate

Verhaltensvertrag der Onboarding-Logik. `@Observable`, host-testbar, Abhängigkeiten injiziert
(`ImmichAPI`, `ConfigStore`, `KeychainStore`).

## StartupGate

```swift
public struct StartupGate: Sendable {
    public init(config: ConfigStore, keychain: KeychainStore)
    public func initialStep() -> OnboardingStep
}
```

- Liefert `done` nur bei vollständigem Zustand (Config mit URL + Album-ID **und** Key im Keychain).
- Sonst den ersten fehlenden Schritt (`server` / `apiKey` / `album`). Siehe Tabelle in
  [data-model.md](../data-model.md).

## OnboardingViewModel

```swift
@Observable
public final class OnboardingViewModel {
    public init(api: @escaping (ServerConfig) -> ImmichAPI,
                config: ConfigStore,
                keychain: KeychainStore)

    // Zustand: step, serverURLInput, apiKeyInput, albums, selectedAlbumID, isBusy, errorMessage
    public func submitServerURL() async   // Schritt 1
    public func submitAPIKey() async      // Schritt 2
    public func loadAlbums() async        // Schritt 3 (laden)
    public func selectAlbum(id: String) async  // Schritt 3 (wählen + abschließen)
    public func reset()                   // US3
}
```

> `api` wird als Factory injiziert, weil der `ImmichAPI`-Client von `ServerConfig` (URL+Key)
> abhängt, die erst im Lauf entstehen. In Tests liefert die Factory einen Client mit `MockTransport`.

### Verhalten je Aktion

- **submitServerURL()**
  - Validiert/normalisiert `serverURLInput` zu `https`-URL; ungültig → `errorMessage`, bleibt bei `server` (FR-003).
  - Ruft `serverVersion()`; Erfolg → `step = apiKey`. `.unreachable`/`.invalidResponse` → Meldung, bleibt `server` (FR-004, SC-003).
- **submitAPIKey()**
  - Baut Client mit eingegebener URL + Key; ruft `albums()` zur Validierung.
  - Erfolg → `keychain.save(key)`; `albums` zwischenspeichern; `step = album` (FR-005).
  - `.unauthorized` → „Ungültiger API-Key", bleibt `apiKey` (SC-002). `.unreachable`/`.invalidResponse` → Meldung, bleibt `apiKey`.
  - Schlägt `keychain.save` fehl → Schritt **nicht** erfolgreich, Meldung (Edge Case).
- **loadAlbums()** / **selectAlbum(id:)**
  - Leere Liste → Hinweis, kein Fehler, keine Auswahl möglich (FR-013).
  - Auswahl: `config.save(AppConfiguration(baseURL, id))`; `step = done` (FR-009).
- **reset()**
  - `config.clear()` + `keychain.delete()`; `step = server`; Eingaben/Key-Input geleert (FR-012, SC-006).

### Invarianten

- `apiKeyInput` wird nie über `config` persistiert oder geloggt (Konstitution III).
- Während `isBusy` keine Doppelaktionen (Buttons gesperrt).
- `done` nur nach erfolgreichem `config.save` mit nicht-leerer Album-ID.

## Tests (Host, Swift Testing, Fakes)

- StartupGate: alle Zeilen der Entscheidungstabelle.
- submitServerURL: ungültige URL; Erfolg; `.unreachable`.
- submitAPIKey: Erfolg (Key landet im Fake-Keychain); `.unauthorized`; Keychain-Schreibfehler.
- selectAlbum: Erfolg (Config gespeichert, `done`); leere Liste → Hinweis.
- reset: Config + Key entfernt, zurück zu `server`.
