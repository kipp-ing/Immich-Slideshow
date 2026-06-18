# Research: Onboarding (Ersteinrichtung)

Phase-0-Entscheidungen. Offene Punkte aus dem Technical Context aufgelöst.

## 1. Server-Erreichbarkeit in Schritt 1 (vor dem API-Key)

**Decision**: Erreichbarkeit über einen **unauthentifizierten Versions-Endpunkt** der Immich-API
prüfen. `ImmichClient` wird um `serverVersion() async throws -> String` erweitert (Route gegen die
laufende Instanz zu bestätigen: `GET /api/server/version`, ältere Stände `GET /api/server-info/version`).
Aufruf mit der eingegebenen URL und leerem API-Key (Endpunkt benötigt keine Auth).

**Rationale**: Schritt 1 trennt „Server gefunden?" von „Key gültig?" (FR-004 vs FR-005) und liefert
dem Nutzer eine präzise Fehlermeldung. Netzwerk bleibt im `ImmichClient`-Modul (eine Quelle für
URLSession/Fehler-Mapping). Konstitution IV: konkrete Route in der Implementierung gegen
`GET /api/server/version` der laufenden Version verifizieren, nicht aus Tutorials übernehmen.

**Alternatives considered**: (a) Schritt 1+2 zusammenlegen und nur `albums()` aufrufen — verworfen,
weil die Spec drei Schritte fordert und die Fehlerursache (nicht erreichbar vs. falscher Key) sonst
verschwimmt. (b) Roher URLSession-Ping in `OnboardingKit` — verworfen, dupliziert Netzwerk-/
Fehlerlogik außerhalb von `ImmichClient`.

## 2. Speicherung des API-Keys (Secret)

**Decision**: `KeychainStore`-Protokoll mit Methoden `save(_:)`, `read()`, `delete()`; reale Impl
`KeychainAPIKeyStore` über `Security` (`SecItemAdd`/`SecItemCopyMatching`/`SecItemDelete`,
`kSecClassGenericPassword`, fester Service/Account). Tests gegen `InMemoryKeychainStore`-Fake auf
dem Host; reale Impl app-gehostet auf dem Simulator.

**Rationale**: Konstitution III (NON-NEGOTIABLE) — Key ausschließlich im Keychain. Protokoll macht
die Logik ohne echten Keychain testbar (Konstitution II). Reset (FR-012) ruft `delete()`.

**Alternatives considered**: Drittbibliothek (KeychainAccess) — verworfen, keine Drittabhängigkeiten
nötig; die Security-API reicht. UserDefaults — durch Konstitution III verboten.

## 3. Persistenz von URL und Album-ID (nicht-geheim)

**Decision**: `ConfigStore`-Protokoll (`load() -> AppConfiguration?`, `save(_:)`, `clear()`); reale
Impl `UserDefaultsConfigStore`. Speichert `baseURL` (String) und `selectedAlbumID` (String).

**Rationale**: Nicht-geheime, kleine Schlüssel-Werte → UserDefaults ist angemessen. Protokoll für
Testbarkeit und um den realen Store gegen einen `InMemoryConfigStore`-Fake zu tauschen.

**Alternatives considered**: Eine einzelne JSON-Datei — verworfen, Overkill für zwei Felder.
CoreData/SwiftData — unnötig schwer.

## 4. Startentscheidung: Onboarding vs. Hauptscreen

**Decision**: `StartupGate` kombiniert `ConfigStore` + `KeychainStore` und liefert beim Start einen
`OnboardingStep` bzw. `done`. Vollständig (URL + Album-ID in Config UND Key im Keychain) → `done`
(Hauptscreen). Fehlt ein Teil → erster fehlender Schritt (FR-001/FR-002/FR-011). Unvollständige
Setups geben den Hauptscreen nie frei.

**Rationale**: Eine einzige, host-testbare Entscheidung statt verstreuter `if`-Checks in der View;
deckt US2 (skip) und „abgebrochenes Onboarding" deterministisch ab.

**Alternatives considered**: Nur ein „onboardingComplete"-Bool in UserDefaults — verworfen, weil es
mit dem realen Vorhandensein des Keys auseinanderlaufen kann (Key gelöscht, Bool bleibt true).

## 5. State-Management der UI

**Decision**: `@Observable OnboardingViewModel` hält Schritt, Eingaben, Lade-/Fehlerzustand und
orchestriert `ImmichAPI` + Stores. SwiftUI-Views binden an das ViewModel; das ViewModel ist
host-testbar ohne SwiftUI.

**Rationale**: MVVM mit `@Observable` ist projektgesetzt (CLAUDE.md). Logik im ViewModel → schnelle
Host-Tests; Views dünn → Simulator-Verifikation.

**Alternatives considered**: Logik direkt in der View (`@State`) — verworfen, nicht isoliert testbar.

## 6. Fehler-Mapping zu Nutzermeldungen

**Decision**: `ImmichError` → nutzerfreundlicher Text im ViewModel: `.unauthorized` →
„Ungültiger API-Key" (zurück zu Schritt 2), `.unreachable` → „Server nicht erreichbar"
(Schritt 1/wiederholen), `.invalidResponse` → „Unerwartete Antwort vom Server". Leere Albumliste →
eigener Hinweis (FR-013), kein Fehler.

**Rationale**: Wiederverwendung der bestehenden, getesteten Fehlerfälle aus `ImmichClient`; klare,
wiederholbare Schritte (FR-010, SC-002/SC-003).

**Alternatives considered**: Rohe Fehlertexte anzeigen — verworfen, nicht nutzerfreundlich.

## 7. URL-Validierung / nur HTTPS

**Decision**: Eingabe normalisieren (trim, ggf. Schema ergänzen/prüfen), nur `https`-URLs
akzeptieren; ungültiges Format wird vor jedem Netzaufruf abgewiesen (FR-003).

**Rationale**: Konstitution IV — keine Klartext-Verbindungen; frühe Validierung spart fehlende
Netz-Roundtrips und gibt klares Feedback.

**Alternatives considered**: HTTP zulassen mit Warnung — verworfen, außerhalb des Scopes.

## 8. Test-Aufteilung Host vs. Simulator

**Decision**: Host (`swift test`): `OnboardingViewModel`, `ConfigStore`, `StartupGate`,
`KeychainStore`-Vertrag gegen Fake. Simulator (`test_sim`, app-gehostet): reale
`KeychainAPIKeyStore`-Impl (save/read/delete) und der Gate-/Flow-Durchlauf end-to-end.

**Rationale**: Der iOS-Keychain existiert nur auf Gerät/Simulator; die übrige Logik ist
Foundation-only und schnell auf dem Host testbar. Entspricht dem in 001 etablierten und
verifizierten Split.

**Alternatives considered**: Alles auf dem Simulator — verworfen, langsamer und unnötig.
