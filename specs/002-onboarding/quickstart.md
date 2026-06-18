# Quickstart / Validation: Onboarding

Beweist das Feature end-to-end. Typen/Verträge siehe [data-model.md](./data-model.md) und
[contracts/](./contracts/).

## Voraussetzungen

- Xcode aktiv (`xcode-select -p`), Swift 6.
- iPad-Simulator (z. B. iPad Pro 11" (M5)).
- Host-Tests ohne Server/Keychain (Fakes); Simulator-Tests über XcodeBuildMCP.

## Host-Tests (Logik, kein Server/Keychain)

Paket `Packages/OnboardingKit` (`swift test` bzw. XcodeBuildMCP Swift-Package-Test):

- `StartupGate` entscheidet skip vs. erster fehlender Schritt (alle Tabellenzeilen).
- `OnboardingViewModel`: Schritt-1-Validierung (URL/`.unreachable`), Schritt-2 (Erfolg speichert Key
  im Fake-Keychain; `.unauthorized`; Schreibfehler), Schritt-3 (Auswahl speichert Config → `done`;
  leere Liste → Hinweis), `reset()` entfernt Config + Key.
- `UserDefaultsConfigStore` persistiert/lädt/löscht (mit eigener `UserDefaults`-Suite).

Ebenso `Packages/ImmichClient` (`serverVersion()`-Tests; bestehende 14 bleiben grün).

## Simulator-Tests (reale Anbindung, app-gehostet)

Scheme „Immich Slideshow" via XcodeBuildMCP `test_sim` (iPad-Sim):

- `KeychainAPIKeyStore` real: `save` → `read` liefert denselben Key → `delete` → `read` ist `nil`.
- Gate/Flow end-to-end: frische Installation startet im Onboarding; nach Durchlauf mit gemockter
  `ImmichAPI` + realem Keychain erreicht ein Neustart den Hauptscreen ohne erneute Eingabe.

## Manuelle Sichtprüfung (Simulator)

App starten (`build_run_sim`): Erststart zeigt Schritt 1 (Server-URL). Mit gültiger URL/Key/Album
durchlaufen → Hauptscreen (Platzhalter). App neu starten → direkt Hauptscreen. Reset → wieder
Schritt 1.

## Akzeptanz-Mapping

| Success Criterion | Validierung |
|-------------------|-------------|
| SC-001 (<2 Min bis Album) | Flow-Test + manuelle Sichtprüfung: drei Schritte mit gültigen Daten → `done`. |
| SC-002 (ungültiger Key, klare Meldung, wiederholbar) | `OnboardingViewModel`-Test `.unauthorized` → Meldung, bleibt `apiKey`. |
| SC-003 (Server nicht erreichbar, wiederholbar) | `OnboardingViewModel`-Test `.unreachable` → Meldung, bleibt `server`. |
| SC-004 (Neustart ohne erneute Eingabe) | `StartupGate`-Test (vollständig → `done`) + Simulator-Flow-Test (Neustart → Hauptscreen). |
| SC-005 (Key nie ungesichert/in Logs) | Key nur über `KeychainStore`; `ConfigStore`/UserDefaults inspizieren → kein Key; reale Keychain-Round-Trip-Test auf dem Sim. |
| SC-006 (Reset, Key entfernt) | `OnboardingViewModel.reset()`-Test: Config + Key weg, zurück zu `server`; realer `delete()` auf dem Sim. |
