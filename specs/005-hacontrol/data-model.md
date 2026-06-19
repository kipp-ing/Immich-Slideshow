# Phase 1 Data Model: HAControl

Flüchtige In-Memory-Entitäten + Topic-/Payload-Struktur. Kein neuer persistenter Speicher (Broker-
Credentials liegen im Keychain).

## Wertmodelle

### BrokerConfig (`Sendable`, `Equatable`)

| Feld | Typ | Bedeutung |
|------|-----|-----------|
| `host` | `String` | Broker-Hostname |
| `port` | `Int` | Broker-Port (TLS, i. d. R. 8883) |
| `username` | `String` | MQTT-Benutzername (Keychain) |
| `password` | `String` | MQTT-Passwort (Keychain) — nie loggen |
| `clientID` / `deviceID` | `String` | stabile, eindeutige Geräte-Kennung (Topics + HA-`identifiers`) |

- Quelle: `BrokerConfigStore.load() -> BrokerConfig?`. `nil` ⇒ keine Fernsteuerung (FR-003).

### PlaybackState (P1, `Equatable`, `Sendable`)

- `case playing` / `case paused`. Abbildung auf State-Payload `ON`=playing / `OFF`=paused (Schalter
  „läuft die Diashow?"). Command `ON`→resume, `OFF`→pause.

### BrightnessLevel (P2)

- `Double` 0.0–1.0 intern; HA-`light` nutzt Helligkeit 0–255 → Mapping/Klemmen auf 0.0–1.0 beim
  Empfang, Rück-Mapping beim State-Echo.

### AlbumSelection (P3)

- aktueller Albumname (String) + Optionsliste (`[String]`) der verfügbaren Alben. Unbekannte Auswahl ⇒
  Zustand unverändert (FR-015).

### ConnectionState (`Equatable`, `Sendable`)

- `case disconnected` / `connecting` / `connected`. Treibt Verfügbarkeit (`online` nur bei
  `connected`) und Reconnect.

## Entitäten (HA) & Topics

Basis-Präfix: `immichslideshow/<deviceID>/`. Verfügbarkeit gemeinsam:
`immichslideshow/<deviceID>/availability` (`online`/`offline`, retained, LWT=`offline`).

| Entität (Priorität) | HA-Component | Command-Topic (subscribe) | State-Topic (retained publish) | unique_id |
|---------------------|--------------|---------------------------|--------------------------------|-----------|
| Pause/Play (P1) | `switch` | `.../switch/set` | `.../switch/state` | `<deviceID>_playback` |
| Helligkeit (P2) | `light` | `.../light/set` | `.../light/state` | `<deviceID>_brightness` |
| Album (P3) | `select` | `.../select/set` | `.../select/state` | `<deviceID>_album` |

- Discovery-Config je Entität: `homeassistant/<component>/<deviceID>/<object>/config` (retained), mit
  `availability_topic`, `command_topic`, `state_topic`, `unique_id`, gemeinsamem `device`-Block
  (`identifiers=[deviceID]`, `name`, `manufacturer`/`model` optional).

## Zustandsübergänge (Coordinator)

```text
            start()/config vorhanden            stop()/Hintergrund/Verlassen
 disconnected ───────────────▶ connecting ──ok──▶ connected ───────────────▶ disconnected
      ▲                                              │   │                         (LWT → offline)
      └───────────── reconnect (Backoff) ───────────┘   │ Command rein / lokale Änderung
                                                         ▼
                                              Aktion über RemoteControlling
                                              + State-Echo (retained) + availability=online
```

- **connected erreicht**: availability=`online`; Discovery (idempotent) publizieren; Command-Topics
  abonnieren; aktuellen Zustand je Entität als State-Echo publizieren.
- **Command rein**: Payload parsen → bei gültig: passende `RemoteControlling`-Aktion; danach **immer**
  echten Zustand als State-Echo publizieren (auch wenn unverändert/ungültig → tatsächlicher Zustand).
- **lokale Änderung** (Callback aus der App, z. B. Nutzer pausiert): State-Echo publizieren.
- **Verbindungsverlust**: Broker publiziert LWT `offline`; Coordinator → `disconnected` → Reconnect.
- **config nil / connect scheitert**: bleibt `disconnected`; Diashow lokal unbeeinflusst (FR-003).

## Invarianten

- Der publizierte State entspricht nach jeder Verarbeitung dem tatsächlichen App-Zustand (kein Phantom).
- `unique_id`/`deviceID` sind stabil ⇒ wiederholte Discovery erzeugt keine Duplikate (SC-005).
- Broker-`password`/`username` erscheinen in keinem publizierten Payload, Log oder Topic (Konstitution
  III).
- Ungültige/unbekannte eingehende Payloads ändern den Zustand nicht und führen nicht zum Absturz
  (FR-011); danach wird der unveränderte echte Zustand zurückgemeldet.
- TLS bleibt aktiv; ohne gültige TLS-Verbindung kein „connected".
