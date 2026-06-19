# Phase 0 Research: PowerManager

Auflösung der offenen technischen Punkte. Keine NEEDS-CLARIFICATION offen (Spec hat keine).

## 1. Naht für den hardwarenahen Zugriff (`ScreenControlling`)

- **Decision**: Ein Protokoll `ScreenControlling` mit `var brightness: Double { get set }` und
  `var isIdleTimerDisabled: Bool { get set }` (`@MainActor`). Die reale Implementierung im App-Target
  (`UIScreenController`) mappt auf `UIScreen.main.brightness` (Double 0.0–1.0) und
  `UIApplication.shared.isIdleTimerDisabled`. Tests nutzen einen `FakeScreenController`, der gesetzte
  Werte in einem Array aufzeichnet.
- **Rationale**: `UIScreen`/`UIApplication` sind UIKit und nur auf dem Simulator/Gerät verfügbar.
  Hinter einem Protokoll bleibt `PowerKit` UIKit-frei und auf dem Host testbar (SPM-Test-Target läuft
  auf dem Host) — exakt das Muster von `ImmichAPI`/`SlideshowTicker` (Konstitution II).
- **Alternatives considered**: Direkter `UIScreen`-Zugriff im Paket → verworfen (nicht host-testbar,
  zieht UIKit ins Paket). `#if canImport(UIKit)`-Verzweigung im Paket → verworfen (testet die echte
  Logik nicht deterministisch, verwischt Modulgrenzen).

## 2. Modell für das weiche Dimmen (`PowerClock` + Ramp)

- **Decision**: Weiches Dimmen als endliche Folge von Zwischenschritten zwischen Start- und Zielwert
  (`PowerConfig.softDimSteps`), zwischen denen über eine injizierte `PowerClock`-Naht gewartet wird
  (`func sleep(for: Duration) async throws`). Real: `Task.sleep`/`ContinuousClock`. Test:
  `ManualClock`, dessen `sleep` sofort zurückkehrt — der Test beobachtet die vom `FakeScreenController`
  aufgezeichneten Zwischen-Helligkeiten. Die Ramp läuft als abbrechbarer `Task`.
- **Rationale**: Deterministische Soft-Dim-Tests ohne echte Wartezeit (SC-004 „mindestens ein
  beobachtbarer Zwischenwert"). Latest-Target-wins durch Abbrechen des laufenden Ramp-Tasks beim
  Setzen eines neuen Ziels (FR-012). Hintergrund stoppt den Task (FR-009/FR-012).
- **Alternatives considered**: `withAnimation`/`UIView`-Animation für die Helligkeit → verworfen
  (`UIScreen.brightness` ist nicht über UIView-Animation animierbar; zudem UIKit-gebunden, nicht
  host-testbar). Core-Animation-Display-Link → unnötig komplex für eine kurze Wertrampe.

## 3. Foreground-only-Gating

- **Decision**: `PowerManager` kennt einen internen „aktiv im Vordergrund"-Zustand. `activate()`
  (Diashow erscheint) erfasst den Helligkeits-Ausgangswert und setzt `isIdleTimerDisabled = true`.
  `didEnterBackground()` setzt `isIdleTimerDisabled = false`, stoppt eine laufende Ramp und
  unterlässt jede Schreibung. `willEnterForeground()` (bei noch aktiver Diashow) setzt
  `isIdleTimerDisabled = true` erneut. `setBrightness(_:animated:)` ist im Hintergrund ein No-Op.
- **Rationale**: Genau Konstitution V / FR-003/FR-004/FR-009. Die Lebenszyklus-Signale liefert
  `SlideshowView` über `scenePhase` und Erscheinen/Verlassen — der `PowerManager` führt keine eigene
  Szenenerkennung.
- **Alternatives considered**: Direktes Lauschen auf `UIApplication`-Notifications im Paket →
  verworfen (UIKit im Paket, schwerer testbar). Die View ist bereits die Quelle der Wahrheit für
  `scenePhase` (siehe 003).

## 4. Restore-on-Exit & Ausgangswert

- **Decision**: Beim ersten `activate()` einer Sitzung wird der aktuelle `brightness`-Wert als
  `baselineBrightness` gemerkt — aber nur „als verändert" markiert, sobald die App tatsächlich eine
  Helligkeit schreibt. `deactivate()` setzt `isIdleTimerDisabled = false` und schreibt — **nur falls
  die App die Helligkeit verändert hat** — `baselineBrightness` zurück. Hat die App nie geschrieben,
  bleibt die Helligkeit unangetastet (FR-011, SC-005). Ist kein Ausgangswert erfassbar, wird beim
  Verlassen keine Helligkeit erzwungen (Edge Case).
- **Rationale**: Verhindert unnötiges/falsches Zurücksetzen und respektiert nutzergesetzte Werte.
- **Alternatives considered**: Immer auf einen festen Default zurücksetzen → verworfen (überschreibt
  Nutzerpräferenz). Ausgangswert persistieren → unnötig (Sitzungs-flüchtig genügt; harte Beendigung
  ist akzeptierte Plattformgrenze).

## 5. Klemmen ungültiger Werte

- **Decision**: `setBrightness` klemmt den Eingabewert auf `0.0...1.0` (`min(max(value, 0), 1)`),
  kein Fehler (FR-006, SC-003).
- **Rationale**: Robuste, vorhersagbare API; Aufrufer (später HAControl) müssen nicht vorvalidieren.

## 6. Verifikation auf dem Simulator

- **Decision**: Logik vollständig host-getestet. Reales Verhalten (Leerlauf-Timer-Flag, tatsächliche
  Bildschirmhelligkeit) wird app-gehostet auf dem iPad-Simulator über XcodeBuildMCP geprüft
  (Screenshot/Smoke + optionaler hermetischer Lebenszyklus-Test über die `--uitest`-Naht mit
  Fake-`ScreenController`).
- **Rationale**: `UIScreen.brightness` ist auf dem Simulator setz-/lesbar; das Wach-halten lässt sich
  nicht „über Zeit" im CI praktisch abwarten, daher wird die Verdrahtung (richtige activate/deactivate-
  Aufrufe an den Lebenszyklus) über die injizierte Naht verifiziert statt über echte Leerlaufzeit.
