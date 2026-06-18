# Inhalt für /speckit.constitution

Diesen Text als Eingabe für den `/speckit.constitution`-Command verwenden.
(Spec Kit formt daraus `.specify/memory/constitution.md`.)

---

ImmichSlideshow ist eine eigenständige iPad-App, die Immich nur als Datenquelle nutzt.
Folgende Prinzipien sind nicht verhandelbar:

**Test-First.** Jede Funktionalität beginnt mit einem fehlgeschlagenen Test. Kein Implementierungscode ohne vorher roten Test. Red → Green → Refactor.

**Modulare Isolation.** Jedes Modul ist über ein Protokoll von seinen Abhängigkeiten entkoppelt (Netzwerk, Keychain, MQTT, Zeit). Tests laufen ohne echten Server, Broker oder Keychain.

**Keine Secrets im Klartext.** Immich-API-Key und MQTT-Credentials liegen ausschließlich im Keychain. Niemals in UserDefaults, Code oder Logs.

**Sicherheit der Transportschicht.** TLS-Validierung wird nicht deaktiviert. Der Immich-Server hat ein gültiges Zertifikat; MQTT läuft über TLS. Self-signed-/Klartext-Verbindungen sind ausdrücklich außerhalb des aktuellen Scopes.

**Plattformgrenzen respektieren.** Die App schaltet das Display nicht physisch aus (iOS-Grenze) und steuert Helligkeit/Idle-Timer nur im Vordergrund. Features werden nicht gegen diese Grenzen entworfen.

**Verifizierbare Akzeptanzkriterien.** Jede Spec endet mit prüfbaren Kriterien (konkrete Eingaben/Ausgaben, Fehlerfälle), nicht mit vagen Qualitätswünschen.

**Schlicht und hell als Default.** UI-Voreinstellungen sind ruhig und hell. Zusatzfunktionen sind opt-in, nicht aufgedrängt.
