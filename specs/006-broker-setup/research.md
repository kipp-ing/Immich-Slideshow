# Phase 0 Research: Broker-Setup

Keine NEEDS-CLARIFICATION offen. Entscheidungen folgen den etablierten Mustern (OnboardingKit).

## 1. Aufteilung Persistenz: Keychain vs. UserDefaults

- **Decision**: Benutzername + Passwort → Keychain (ein Generic-Password-Item, Wert = JSON
  `{username,password}`, idempotentes Überschreiben wie `KeychainAPIKeyStore`). Host + Port → UserDefaults
  (nicht geheim). „Vollständig konfiguriert" gilt nur, wenn beide Teile vorhanden + gültig sind.
- **Rationale**: Konstitution III (Credentials nur Keychain); Host/Port sind keine Geheimnisse und als
  normale Einstellung handhabbar. Spiegelt exakt das OnboardingKit-Muster (ConfigStore=UserDefaults,
  KeychainStore=Keychain).
- **Alternatives considered**: Alles in den Keychain (auch Host/Port) — möglich, aber inkonsistent zum
  bestehenden Muster und ohne Sicherheitsgewinn. Alles in UserDefaults — verboten (Credentials).

## 2. Atomarität

- **Decision**: `save(_:)` validiert zuerst; nur bei gültigem `BrokerSettings` werden Keychain **und**
  UserDefaults geschrieben. `load()` liefert nur ein vollständiges Ergebnis (beide Teile vorhanden),
  sonst `nil`. `clear()` entfernt beide Teile.
- **Rationale**: FR-004 — nie unvollständig persistieren; die Fernsteuerung darf keine halbe Config
  sehen.

## 3. Bridge zu Feature 005 (`BrokerConfigStore`)

- **Decision**: `BrokerConfigProvider` (in BrokerSetupKit) hängt an `HAControlKit` und konformiert
  dessen `BrokerConfigStore`. `load() -> BrokerConfig?` baut aus den gespeicherten `BrokerSettings` +
  der **injizierten** Geräte-ID ein `BrokerConfig`; fehlt etwas → `nil` (FR-005).
- **Rationale**: Saubere Schichtung — 006 ist die einzige Stelle, die Eingabe-Persistenz und die
  005-Konsumentenschnittstelle verbindet. Hält 005 frei von Persistenz-Details.
- **Alternatives considered**: `BrokerConfigStore`-Impl direkt im App-Target — möglich, aber dann ist
  die Bridge-Logik nicht host-testbar; Provider im Paket ist testbar.

## 4. Stabile Geräte-ID

- **Decision**: `UIDevice.current.identifierForVendor?.uuidString` im App-Target erzeugen und in den
  `BrokerConfigProvider` injizieren (Closure/Wert). Über Neustarts stabil (solange App installiert).
- **Rationale**: FR-010; UIKit-Bezug bleibt im App-Target, Paket bleibt host-testbar/UIKit-frei.
- **Alternatives considered**: Zufalls-UUID persistieren — zusätzlicher Speicher ohne Mehrwert;
  `identifierForVendor` genügt für ein Einzelgerät.

## 5. Passwort-Anzeige (P2)

- **Decision**: Das Eingabefeld ist ein SecureField; ein bereits gespeichertes Passwort wird **nicht**
  im Klartext vorbefüllt — stattdessen leer mit Hinweis „gesetzt"; nur ein neu eingegebenes Passwort
  überschreibt. Beim Laden zum Anzeigen wird das Passwort nicht in die UI gespiegelt.
- **Rationale**: FR-009; minimiert Klartext-Exposition.

## 6. Einstieg in das Setup

- **Decision**: Über das bestehende unaufdringliche Long-Press-Menü der `SlideshowView` (neben „Reset")
  einen Eintrag „Broker einrichten" ergänzen, der `BrokerSetupView` als Sheet zeigt.
- **Rationale**: Konstitution VII — kein neues, aufdringliches UI; nutzt den vorhandenen,
  versteckten Zugang.
- **Alternatives considered**: Eigener Onboarding-Schritt — verworfen (Fernsteuerung ist optional, soll
  den Erst-Flow nicht verlängern).

## 7. Verifikation

- **Decision**: Validierung + Provider host-getestet (In-Memory-Fake). Reale Keychain-/UserDefaults-
  Persistenz + Form app-gehostet auf dem Simulator (Round-Trip + „kein Passwort in UserDefaults").
- **Rationale**: Keychain läuft zuverlässig nur auf dem Simulator/Gerät (vgl. OnboardingKit).
