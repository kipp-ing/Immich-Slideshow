# Data Model: Onboarding (Ersteinrichtung)

Wertmodelle und Zustände. Verträge der Protokolle siehe [contracts/](./contracts/).

## Entities

### AppConfiguration

Die vollständige, nicht-geheime App-Konfiguration nach dem Onboarding.

| Feld | Typ | Beschreibung | Validierung |
|------|-----|--------------|-------------|
| `baseURL` | `URL` | Basis-Adresse der Immich-Instanz | nur `https`; gültiges URL-Format |
| `selectedAlbumID` | `String` | Kennung des gewählten Albums | nicht leer |

- `Sendable`, `Equatable`. Persistiert über `ConfigStore` (UserDefaults).
- Der API-Key ist **nicht** Teil dieses Modells (liegt im Keychain) — bewusste Trennung
  geheim/nicht-geheim (Konstitution III).

### API-Key (Secret)

- Kein eigenes Modell; ein `String`, ausschließlich über `KeychainStore` gehandhabt.
- Erscheint nie in `AppConfiguration`, UserDefaults, Logs oder committeten Dateien.

### Album (wiederverwendet)

- Aus `ImmichClient`: `Album { id: String, name: String }`. Wird in Schritt 3 zur Auswahl gelistet;
  `id` fließt als `selectedAlbumID` in die `AppConfiguration`.

### OnboardingStep

Aufzählung des aktuellen Schritts / Startzustands.

| Fall | Bedeutung |
|------|-----------|
| `server` | Schritt 1: Server-URL eingeben/prüfen |
| `apiKey` | Schritt 2: API-Key eingeben/validieren |
| `album` | Schritt 3: Album wählen |
| `done` | Onboarding abgeschlossen → Hauptscreen |

### OnboardingViewModel (Zustand)

`@Observable`. Beobachtbarer UI-Zustand und Eingaben.

| Feld | Typ | Beschreibung |
|------|-----|--------------|
| `step` | `OnboardingStep` | aktueller Schritt |
| `serverURLInput` | `String` | Roh-Eingabe Server-URL |
| `apiKeyInput` | `String` | Roh-Eingabe API-Key (nur im Speicher, nie persistiert außer Keychain) |
| `albums` | `[Album]` | geladene Albumliste (Schritt 3) |
| `selectedAlbumID` | `String?` | aktuelle Auswahl |
| `isBusy` | `Bool` | laufender Netzaufruf (Lade-/Button-Sperre) |
| `errorMessage` | `String?` | nutzerfreundliche Fehlermeldung oder `nil` |

## State Transitions

```text
server  --(URL gültig & erreichbar)-->        apiKey
apiKey  --(Key gültig: albums() ok)-->         album       (Key im Keychain gespeichert)
album   --(Album gewählt & gespeichert)-->     done        (Config persistiert)

Fehlerzweige (bleiben im Schritt, errorMessage gesetzt, wiederholbar):
server  --(ungültige URL / .unreachable / .invalidResponse)-->     server
apiKey  --(.unauthorized)-->                                        apiKey
apiKey  --(.unreachable / .invalidResponse)-->                      apiKey
album   --(leere Albumliste)-->                                     album (Hinweis, keine Auswahl)

Reset (US3): jeder Zustand --(reset: Config.clear + Keychain.delete)--> server
```

## Startup-Entscheidung (StartupGate)

| Config vorhanden? | Key im Keychain? | Ergebnis |
|-------------------|------------------|----------|
| URL + Album-ID | ja | `done` (Hauptscreen) |
| URL + Album-ID | nein | `apiKey` |
| URL ohne Album-ID | – | `album` (wenn Key vorhanden) bzw. `apiKey` |
| keine/teilweise URL | – | `server` |

> Regel: Nur ein **vollständiger** Zustand (URL + Album-ID + Key) ergibt `done` (FR-011).

## Validation Rules (aus Requirements)

- **FR-003**: `serverURLInput` muss zu einer gültigen `https`-URL normalisierbar sein, sonst Abweisung.
- **FR-006**: API-Key nur über `KeychainStore`; nie in `ConfigStore`/Logs.
- **FR-009**: `selectedAlbumID` nicht leer, bevor `done`.
- **FR-012**: Reset entfernt Config **und** Key.
- **FR-013**: leere `albums` → Hinweis statt Sackgasse.
