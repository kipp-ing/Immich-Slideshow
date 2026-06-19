# Phase 0 Research: HAControl

Auflösung der offenen technischen Punkte. Keine NEEDS-CLARIFICATION offen (Scope per Vorab-Entscheid
geklärt: MQTT-Bibliothek + MVP-Schnitt Pause/Play+Verfügbarkeit).

## 1. MQTT-Client: Bibliothek statt Eigenbau

- **Decision**: `swift-server/mqtt-nio` (MQTTNIO) als SPM-Abhängigkeit, isoliert im Target
  `HAControlMQTT`. Unterstützt MQTT 3.1.1 und 5.0, async/await, TLS (über NIOSSL bzw. auf Apple-
  Plattformen NIOTransportServices/Network.framework), Last-Will-and-Testament und Auto-Reconnect.
- **Rationale**: MQTT inkl. Keepalive/PINGREQ, Paket-Framing, QoS, LWT und TLS von Hand auf
  `Network.framework` zu bauen ist groß und sicherheitskritisch. Eine etablierte Lib senkt Risiko/Zeit
  erheblich; die Isolation im eigenen Target hält den Kern (`HAControlKit`) dependency- und nio-frei.
- **Alternatives considered**: (a) Hand-Roll auf `Network.framework` — verworfen (Aufwand/Risiko, kein
  Mehrwert). (b) `CocoaMQTT` — solide, aber `mqtt-nio` integriert TLS/async/await sauberer und ist
  serverseitig breit erprobt. (c) Kein MQTT (HTTP-Polling) — passt nicht zu HA-Discovery/LWT.

## 2. TLS

- **Decision**: TLS verpflichtend über die `mqtt-nio`-TLS-Konfiguration (Standard-Zertifikatsprüfung
  aktiv). Port i. d. R. 8883. Keine Deaktivierung der Validierung; Self-signed ist out of scope.
- **Rationale**: Konstitution IV. Der Broker hat (Annahme) ein gültiges Zertifikat — analog zum
  Immich-Server.
- **Alternatives considered**: Klartext 1883 / `allowInsecure` — verworfen (Konstitution IV).

## 3. Home-Assistant-MQTT-Discovery-Konvention

- **Decision**: Pro Entität eine Discovery-Config unter
  `homeassistant/<component>/<node_id>/<object_id>/config` (retained), mit gemeinsamer `device`-Angabe
  (stabile `identifiers` = Geräte-ID) und gemeinsamem `availability_topic`. Komponenten: `switch`
  (Pause/Play, P1), `light` (Helligkeit, P2), `select` (Album, P3). Jede Entität hat `unique_id` aus
  `<deviceID>_<entity>` → keine Duplikate (SC-005).
- **Rationale**: Standard-HA-Discovery; retained Config + stabile IDs sorgen dafür, dass HA das Gerät
  nach Neustart/Reconnect ohne Duplikate wiederfindet.
- **Alternatives considered**: Manuelle YAML-Konfiguration in HA — verworfen (kein Auto-Setup, schlechte
  UX). Ein einziges „device_automation" — passt nicht zu Steuer-Entitäten.

## 4. Topic-Struktur & Zustands-Rückmeldung

- **Decision**: Basis-Präfix `immichslideshow/<deviceID>/`. Je Entität ein Command-Topic (`.../set`,
  abonniert) und ein State-Topic (`.../state`, retained publiziert). Verfügbarkeit:
  `immichslideshow/<deviceID>/availability` mit Payloads `online`/`offline`. Nach jedem Befehl **und**
  nach jeder lokalen Änderung wird der echte Zustand auf das State-Topic publiziert (Echo) → HA spiegelt
  den App-Zustand (FR-009, SC-002/SC-003).
- **Rationale**: Optimistische HA-Anzeige wird durch retained State-Echo korrigiert; kein Auseinander-
  laufen. Geräte-ID-basierte Topics sind eindeutig pro Gerät.
- **Alternatives considered**: Nur Command, kein State — verworfen (HA spiegelt sonst nicht den echten
  Zustand). Nicht-retained State — verworfen (HA verlöre den Zustand bei Neustart).

## 5. Verfügbarkeit (LWT) & Reconnect

- **Decision**: Beim Verbinden wird ein LWT auf das availability-Topic mit `offline` (retained)
  registriert; nach erfolgreichem Connect publiziert die App `online` (retained). Bei Verbindungsverlust
  publiziert der Broker automatisch das LWT (`offline`). Reconnect mit Backoff über die Lib; nach
  Reconnect erneut `online` + Discovery (idempotent) + aktueller Zustand.
- **Rationale**: FR-004/FR-005, SC-004. Selbstheilung ohne Nutzeraktion.
- **Alternatives considered**: App publiziert „offline" selbst beim Beenden — ergänzend möglich, aber
  LWT deckt den unerwarteten Abbruch ab (der wichtige Fall).

## 6. Anbindung an Slideshow/Power ohne Paket-Kopplung

- **Decision**: `RemoteControlling`-Protokoll im Kern definiert die Steuerfläche (pause/resume,
  setBrightness, selectAlbum, plus Lese-Zustände/Albumliste und einen Änderungs-Callback für lokale
  Zustandsänderungen). Das App-Target implementiert es als Adapter auf `SlideshowViewModel` +
  `PowerManager`. So bleibt `HAControlKit` frei von `SlideshowKit`/`PowerKit`.
- **Rationale**: Konstitution II (Isolation); erlaubt Host-Tests des Coordinators mit einem Fake-
  Control. Lokale Änderungen (Nutzer pausiert in der App) lösen über den Callback ein State-Echo aus
  (SC-003).
- **Alternatives considered**: `HAControlKit` direkt von Slideshow/Power abhängig — verworfen (Kopplung,
  schwerer testbar, Zyklusgefahr).

## 7. Broker-Credentials aus dem Keychain

- **Decision**: `BrokerConfigStore`-Protokoll liefert `BrokerConfig?` (host/port/user/pass + „gültig?").
  Reale Impl im App-Target über den bestehenden Keychain-Mechanismus (analog `KeychainAPIKeyStore`).
  Fehlt die Config oder ist sie ungültig → kein Verbindungsversuch, Diashow läuft lokal weiter (FR-003).
- **Rationale**: Konstitution III; Eingabe-/Onboarding-UI ist separat/out of scope.
- **Alternatives considered**: Credentials in UserDefaults/Config-Datei — verboten (Konstitution III).

## 8. Lebenszyklus & Foreground

- **Decision**: Der Coordinator wird beim Erscheinen der Diashow gestartet (verbinden) und beim
  Verlassen/Hintergrund gestoppt/getrennt (→ LWT „offline"). Helligkeitsbefehle delegieren an den
  PowerManager, der selbst foreground-gated ist (Konstitution V).
- **Rationale**: iOS gibt im Hintergrund die Kontrolle/Netz auf; „offline" im Hintergrund ist korrektes,
  ehrliches Verhalten.
- **Alternatives considered**: Hintergrund-Dauerverbindung — unzuverlässig/Plattformgrenze; verworfen.

## 9. Verifikation

- **Decision**: Kern-Logik (Discovery-Payloads, Topics, Command→Aktion, State-Echo, Verfügbarkeit/
  Reconnect, robuste Nutzlasten) vollständig host-getestet über Fake-Transport/Fake-Control. Echte
  TLS-Verbindung + HA-Sichtbarkeit manuell gegen einen realen Broker (nicht im CI).
- **Rationale**: Deterministische, schnelle Tests ohne Broker; die Lib-Integration ist dünn und wird
  manuell smoke-getestet.
