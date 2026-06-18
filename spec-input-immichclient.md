# Inhalt für /speckit.specify — Feature 1: ImmichClient

Diesen Text als Eingabe für den `/speckit.specify`-Command verwenden.
Beschreibt **was/warum**, nicht **wie** (kein Code, keine konkrete Lib-Wahl — das kommt im /speckit.plan).

---

Als Nutzer möchte ich, dass die App sich mit meinem Immich-Server verbindet und die Bilder eines von mir gewählten Albums laden kann, damit die Slideshow Inhalte hat.

**Umfang dieses Features:** nur die Datenanbindung. Keine UI, keine Slideshow-Darstellung — das sind spätere Features.

**Verhalten:**
- Die App nimmt eine Server-Basis-URL (HTTPS) und einen API-Key entgegen.
- Sie authentifiziert jede Anfrage über den API-Key (Header `x-api-key`).
- Sie kann die Liste der Alben des Nutzers abrufen (Name + ID je Album).
- Sie kann zu einem gewählten Album dessen Bild-Assets abrufen (IDs + nötige Metadaten).
- Sie kann für ein Asset ein herunterskaliertes Vorschaubild laden (nicht das Original), zur Anzeige geeignet.

**Fehlerfälle, die sauber behandelt werden müssen:**
- Falscher/abgelaufener API-Key (401) → klar unterscheidbarer Fehler.
- Server nicht erreichbar / Timeout → klar unterscheidbarer Fehler.
- Leeres Album → leere, aber gültige Liste (kein Crash).

**Akzeptanzkriterien (verifizierbar):**
- Gültige Album-JSON-Antwort wird korrekt in Album-Modelle geparst.
- Jede ausgehende Anfrage trägt den `x-api-key`-Header.
- Eine 401-Antwort führt zu einem als „nicht autorisiert" erkennbaren Fehler, nicht zu einem generischen.
- Ein Timeout führt zu einem als „nicht erreichbar" erkennbaren Fehler.
- Das Laden eines Albums ohne Assets liefert eine leere Liste ohne Fehler.
- Die gesamte Logik ist gegen einen Mock-Transport testbar, ohne echten Server.

**Bewusst außerhalb des Scopes:** self-signed-Zertifikate, lokale Klartext-Verbindungen, Caching-Strategie, Offline-Modus. Der Server hat ein gültiges Zertifikat.
