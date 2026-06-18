# Phase 0 Research: SlideshowView

Auflösung der offenen technischen Entscheidungen aus dem Plan. Keine NEEDS-CLARIFICATION offen — die
Spec-Assumptions sind konservativ; hier wird der technische Ansatz festgelegt.

## 1. Timer-Seam für deterministische Wechsel-Tests

**Decision**: Ein injizierbares Protokoll `SlideshowTicker` mit einer asynchronen
`waitForNextTick()`-Semantik. Produktiv liefert `RealTicker(interval:)` über `Task.sleep` (bzw.
`ContinuousClock`) reale Intervalle; in Tests treibt ein `ManualTicker` jeden Wechsel explizit
(Test ruft „tick" auf, das ViewModel rückt vor). Die reine Schrittlogik (`advance()`) ist zudem
direkt aufrufbar und ohne Ticker testbar.

**Rationale**: Echte `Task.sleep`-Wartezeiten machen Tests langsam und flaky. Die Konstitution
(Prinzip II) verlangt injizierte Zeit; CLAUDE.md verlangt, Timer-Test-Design inline zu halten. Eine
schmale Ticker-Naht trennt „wann" (Zeit) von „was" (Vorrücken) und macht beides isoliert prüfbar.

**Alternatives considered**:
- `Timer`/`Combine`-Publisher: schwer ohne echte Zeit zu testen, Combine zieht Zusatzkomplexität.
- `swift-async-algorithms` `AsyncTimerSequence`: Drittabhängigkeit, vermeidbar.
- Roher `Task.sleep` direkt im ViewModel ohne Naht: nicht deterministisch testbar — verworfen.

## 2. Bild-Cache: Eviction-Strategie

**Decision**: Eigener, größenbegrenzter LRU-Cache (`ImageCache`) über `Data` je `assetID`, mit festem
`countLimit`; bei Überschreitung wird der am längsten nicht genutzte Eintrag verworfen. Reiner
Wertespeicher, deterministisch, ohne UIKit.

**Rationale**: `NSCache` evictet nicht deterministisch (System entscheidet) → SC-004 („überschreitet
Obergrenze nicht") wäre nicht prüfbar. Ein kleiner eigener LRU mit hartem Count-Limit ist testbar und
hält den Speicher im Dauerbetrieb stabil. Preview-Thumbnails sind klein; ein Count-Limit (statt
Byte-Limit) genügt für v1.

**Alternatives considered**:
- `NSCache`: nicht deterministisch testbar — verworfen für die Kernlogik.
- Unbegrenzter Dictionary-Cache: Speicher wächst unbegrenzt (verletzt FR-007/SC-004) — verworfen.
- Byte-basiertes Limit: für v1 überdimensioniert; Count-Limit reicht (Assumption).

## 3. Bilddaten vs. dekodierte Bilder (UIKit-Grenze)

**Decision**: `SlideshowKit` cached rohe Preview-`Data` (aus `preview(assetID:)`). Das Dekodieren zu
`Image`/`UIImage` passiert in der SwiftUI-Schicht (App-Target). Das Paket bleibt UIKit-frei.

**Rationale**: Paket-Tests laufen auf dem Host (SPM-Limitierung, siehe Memory). Hielte der Cache
`UIImage`, wäre das Paket nicht mehr sauber host-testbar. `Data`-Caching ist plattformneutral; das
Dekodieren kleiner Previews ist günstig und gehört zur Render-Schicht, die ohnehin auf dem Simulator
verifiziert wird.

**Alternatives considered**:
- Dekodierte `UIImage` im Cache: bessere Render-Performance, aber bricht Host-Testbarkeit — verworfen
  für v1 (Previews sind klein genug).

## 4. Prefetch-Strategie

**Decision**: Beim Anzeigen von Index *i* wird sichergestellt, dass die Daten für *i+1* (und optional
*i+2*, Prefetch-Tiefe aus `SlideshowConfig`) im Cache liegen — angestoßen als nebenläufige Tasks,
die das laufende Bild nicht blockieren. Vorrücken nutzt zuerst den Cache; fehlt das Bild noch, wird
auf seinen Abruf gewartet, ohne die aktuelle Anzeige einzufrieren.

**Rationale**: Erfüllt SC-003 (kein Ladeflackern) bei minimalem Speicher (nur 1–2 voraus). Wrap-around
am Listenende wird beim Index-Modulo berücksichtigt, damit auch der Schleifen-Übergang vorgeladen ist.

**Alternatives considered**:
- Gesamtes Album vorladen: Speicher/Bandbreite unnötig — verworfen.
- Kein Prefetch (synchron beim Wechsel laden): sichtbares Flackern — verworfen (verletzt SC-003).

## 5. Skip-on-Error & Reihenfolge

**Decision**: Reihenfolge = vom Album gelieferte Reihenfolge, gefiltert auf Standbilder (`Asset.type`
== Bild; Videos/sonstige übersprungen, FR-011). Schlägt der Preview-Abruf eines Bildes fehl, wird der
Index übersprungen und das nächste ladbare Bild gezeigt. Sind **alle** Bilder unladbar bzw. die Liste
leer/nicht abrufbar → Leer- bzw. Fehlerzustand.

**Rationale**: FR-008/SC-005 verlangen Fortlauf trotz Einzelfehler; FR-009/FR-010 die klaren
Sonderzustände. `Asset.type` (bereits im Modell, String z. B. „IMAGE"/„VIDEO") trägt die Filterung.

**Alternatives considered**:
- Fehlerbild/Platzhalter statt Skip: widerspricht dem ruhigen Default — verworfen.
- Endlos-Retry desselben Bildes: könnte die Show blockieren — verworfen (Skip + späterer Schleifen-
  Durchlauf versucht erneut).

## 6. Foreground-only Timer (Plattformgrenze)

**Decision**: Das App-Target beobachtet `scenePhase`. `.active` → Ticker läuft (`resume`); `.inactive`
/`.background` → Ticker pausiert (`pause`). Das ViewModel stellt `pause()`/`resume()` bereit; die
View verdrahtet sie an `scenePhase`.

**Rationale**: Konstitution V / FR-012 — iOS gibt im Hintergrund die Kontrolle zurück; ein
weiterlaufender Timer wäre wirkungslos und verschwendet Arbeit. Bei Rückkehr setzt die Show fort.

**Alternatives considered**:
- Timer im Hintergrund weiterlaufen lassen: gegen Plattformgrenze, unzuverlässig — verworfen.

## 7. Fade-Übergang in SwiftUI

**Decision**: Überblendung über Opacity-Transition mit `withAnimation(.easeInOut)` beim Wechsel des
aktuellen Bildes (z. B. `.id(currentAssetID).transition(.opacity)`). Schlicht, kein Ken-Burns/Slide.

**Rationale**: FR-004 verlangt ein sanftes Fade; FR-013/Konstitution VII verlangen Schlichtheit.
Verifikation visuell auf dem Simulator (XcodeBuildMCP-Screenshot/Video), nicht im Host-Test.

**Alternatives considered**:
- Ken-Burns/Slide/Custom-Transitions: opt-in, gehört zu ThemeSettings (#5) — out of scope.

## 8. Authentifizierter Client aus der gespeicherten Konfiguration

**Decision**: Beim Routing nach `.done` baut das App-Target aus `AppConfiguration.baseURL` +
Keychain-API-Key einen `ServerConfig` und daraus einen `ImmichClient`, der dem `SlideshowViewModel`
als `ImmichAPI` injiziert wird (zusammen mit `selectedAlbumID`).

**Rationale**: Die Onboarding-Naht liefert URL+Album (ConfigStore) und Key (Keychain). Der Slideshow-
Teil braucht einen authentifizierten Client für `assets()`/`preview()`. Aufbau im App-Wiring hält das
Secret aus dem Paket heraus (Konstitution III).

**Alternatives considered**:
- Client im Paket aus Stores bauen: zöge Keychain/Secret-Handling ins Paket — verworfen.
