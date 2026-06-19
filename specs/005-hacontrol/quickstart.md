# Quickstart & Validation: HAControl

Runnable-Validierung. Host-Tests sichern die Logik (ohne Broker); die echte TLS-Verbindung und die
HA-Sichtbarkeit werden manuell gegen einen realen Broker verifiziert (nicht im CI).

## Voraussetzungen

- Features 003 (Slideshow, Pause/Resume + Albumliste/-wechsel) und 004 (PowerManager, Helligkeit)
  vorhanden — über den `RemoteControlling`-Adapter angebunden.
- Neues Paket `Packages/HAControlKit` (+ Target `HAControlMQTT`) ins App-Target eingebunden.
- Gültige Broker-Daten im Keychain (Eingabe-UI ist separat/out of scope) — für Host-Tests injiziert.

## Logik-Tests (Host, schnell)

```text
swift test  (im Paket Packages/HAControlKit)  bzw. test_sim für das App-Target
```

- `FakeMQTTTransport` zeichnet `connect(will:)`/`publish`/`subscribe` auf und speist eingehende Commands
  ein; `FakeRemoteControl` zeichnet Steueraktionen auf. Discovery/Topics sind reine Funktionen.

## Akzeptanz-Mapping (Spec → Validierung)

| Kriterium | Validierung |
|-----------|-------------|
| **SC-001** Pause/Play-Schalter + Online sichtbar | Coordinator-Test: `start()` (gültige Config) → `connect(will: offline)`, availability=`online`, Discovery-Config für `switch` publiziert, `switch/set` abonniert. |
| **SC-002** Fern-Pause/Play wirkt + Echo | Coordinator-Test: `switch/set OFF` → `control.pause()`, State-Echo=`OFF`; `ON` → `resume()`, Echo=`ON`. |
| **SC-003** lokale Änderung spiegelt in HA | Coordinator-Test: `control.onLocalChange()` nach lokaler Pause → State-Echo=`OFF`. |
| **SC-004** Abbruch→offline, Reconnect→online | Coordinator-Test: `connectionEvents` false→true → erneut availability=`online` + Discovery + Echo. LWT-Will=`offline` bei `connect`. |
| **SC-005** keine HA-Duplikate | Discovery-Test: `unique_id == "<deviceID>_<entity>"`, stabile Topics; doppeltes `start()`/Reconnect publiziert dieselben (retained) Configs ohne neue IDs. |
| **SC-006** Broker weg → Diashow läuft weiter | Coordinator-Test: `configStore.load()==nil` bzw. `connect` wirft → kein Crash, `connection==.disconnected`, keine Steueraktion erzwungen. |
| **SC-007** keine Credentials geleakt | Test/Review: keine `password`/`username` in publizierten Payloads/Topics; kein Logging der Credentials. |
| **SC-008** (P2) Helligkeit fern | Coordinator-Test: `light/set` → `control.setBrightness(clamp)`, State-Echo=angewandter Wert. |
| **SC-009** (P3) Album fern | Coordinator-Test: `select/set <gültig>` → `selectAlbum`, Echo neue Auswahl; `<ungültig>` → no-op, Echo unverändert. |

## Manuelle Broker-Verifikation (out of CI)

1. Gültige Broker-Daten im Keychain hinterlegen; Diashow starten.
2. In Home Assistant erscheint ein Gerät „Immich Slideshow" mit Schalter + Verfügbarkeit; (P2) Licht;
   (P3) Album-Auswahl.
3. Schalter in HA betätigen → Diashow pausiert/läuft; HA-Zustand spiegelt die App.
4. iPad-App in den Hintergrund/Diashow verlassen → Gerät wird in HA „offline" (LWT); zurück → „online".
5. TLS prüfen: Verbindung nur über TLS-Port; keine Klartext-Verbindung.

## Out of Scope (nicht hier prüfen)

- Onboarding-/Einstellungs-UI für Broker-Daten (separates Feature).
- Cloud ohne lokalen Broker, Mehr-Geräte-Setups, HA-Automationen/Szenen.
- Self-signed/Klartext-MQTT (keine TLS-Ausnahme).
