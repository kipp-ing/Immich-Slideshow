# App Store Listing — OwnFrame

Copy-paste source for App Store Connect. Plain, factual tone on purpose — the audience is
self-hosters; they distrust marketing language. Field limits noted per section.

Two locales are configured in ASC: **en-US** (primary — the sections below) and **de-DE**
(under "German listing"). Both were pushed to the iOS **1.1** version record on 2026-07-26;
until then both carried the pre-rename English text. The push script lives in the session
scratchpad, not the repo — the API recipe is the `appStoreVersionLocalizations` /
`appInfoLocalizations` note in `docs/handover-release-prep.md`.

## Name (30 chars max)

    OwnFrame

8/30 chars.

## Subtitle (30 chars max)

    Your photos, your own frame

27/30 chars. Source-neutral on purpose — it covers an Immich server, a shared
link, and the Apple Photos / iCloud library that shipped with 900.

## Promotional text (170 chars max, changeable without review)

    Your photos on the wall: paste an Immich shared link and the slideshow
    starts. Share an album with your loved ones — when you update it, their
    frame follows.

157/170 chars. In ASC on both 1.0 and 1.1. A third sentence with the
iOS 17 / old-iPad hook overflowed 170 (214) and was dropped; promo text is
changeable without review, so a ≤170 variant can be re-added anytime.

## Description (4000 chars max)

```
OwnFrame turns an iPad into a photo frame for your own Immich server.

Whether you run your own Immich server or someone shared an album link with you: this app puts that album on the wall. It talks directly to the Immich server over its REST API. No data is collected — it's all yours.

SET UP IN UNDER A MINUTE
• Paste an Immich shared link and the slideshow starts. If the link has a password, you're asked for it — that's it.
• Or connect with your server URL and an API key to browse your albums in a searchable picker.
• You can also share an Immich link straight into the app from Safari or another app.

THE SLIDESHOW
• Full screen, one photo at a time, with cross-fades, dissolves, or slides — every transition is included.
• Sequential or shuffle, per-photo duration, fit or fill, image quality — every option applies live, no restart.
• Tap for controls: pause, previous/next, an album browser, and a photo info overlay (date and location).

MADE TO RUN ALL DAY
• Keeps the screen awake and lets you dim the brightness for ambient use.
• Runs on older iPads (iPadOS 17 and up) — a retired iPad makes a good frame.

HOME ASSISTANT, IF YOU WANT IT
• Point the frame at your MQTT broker (TLS) and it appears in Home Assistant on its own, no unlock needed: what's playing, the current photo with its date and place, the photo count, and an availability sensor.
• Publishing the photo image itself to your broker is off by default — strictly opt-in, and also included.
• Driving the frame from Home Assistant is part of the Supporter Unlock: play/pause, brightness, album selection, next/previous, and every display setting as controllable entities — plus Siri Shortcuts and App Intents.
• Through Home Assistant's HomeKit Bridge those controls also work from the Apple Home app and Siri.

WHAT'S INCLUDED, WHAT ONE UNLOCK ADDS
• The frame is free and stays whole: every source (your own server, a shared link, or your Photos library), the full slideshow with all transitions, shuffle, timing, fit, quality, brightness, keep-awake, the album browser, the photo info overlay, and the Home Assistant telemetry above.
• One optional Supporter Unlock adds everything else in a single one-time purchase: Ken Burns motion, the clock overlay, and full Home Assistant remote control — every controllable entity, Siri Shortcuts, and App Intents.
• A one-time purchase — no subscriptions, ever. Family Sharing is on, and one purchase covers iPad, iPhone, and Apple TV.
• Where your money goes: the Supporter Unlock covers the project's running costs — developer account, AI tools, test hardware — and everything beyond that goes back to open-source projects that serve the community.

PRIVACY
• The app talks only to the server you configure (and your MQTT broker, if you set one up). 
• API keys, shared-link passwords, and broker credentials are stored in the device keychain.
• The source code is public (Fair Source; becomes MIT after two years): github.com/kipp-ing/OwnFrame

HONEST LIMITS
• You need an Immich server reachable over HTTPS with a valid certificate — or a shared link from one. Self-signed certificates aren't supported yet.
• iOS doesn't let apps switch the display off; the app dims the screen instead. Keep-awake and brightness control work while the app is in the foreground — on a dedicated frame that's exactly where it lives.
• On Apple TV the clock overlay isn't available yet; Ken Burns motion is.

This is an independent app. It is not affiliated with or endorsed by Immich or FUTO.
```

~3,400/4,000 chars. The "WHAT'S INCLUDED…" section and the reworked Home Assistant
bullets landed with the 1100 purchase gate (2026-07-20); on 2026-07-23 (`76c9b78`) the two
tiers (Pro + Automation) and the bundle were consolidated into a single **Supporter Unlock**,
so this section now names one product, not three. Before the gate the listing described
Ken Burns and full HA control as if they were free, which the gated build would have made
untrue. No price points here on purpose: pricing is set in ASC at submission (FR-1100-06).

## Keywords (100 chars max)

    immich,server,slideshow,selfhosted,digital,wall,display,home assistant,mqtt,album,kiosk,ambient

95/100 chars. Words in the name and subtitle are indexed automatically, so *photo*, *photos*
and *frame* stay out. **`immich` and `server` are back in as of 2026-07-26**: they used to be
covered by the old subtitle ("Slideshow for your own server"), and the source-neutral rewrite
dropped both — an app whose whole point is Immich has to be findable under it. `self-hosted`
came out to make room; the tokenizer splits it into *self* + *hosted* anyway and `selfhosted`
covers the unhyphenated search.

## German listing (de-DE)

Pushed to ASC 2026-07-26 alongside the English fields. Written *for* German, not
translated word-for-word, and the terminology matches what the app itself ships in the
String Catalogs (topic 300): Diashow, Quelle, geteilter Link, Fotos-Mediathek,
Supporter-Freischaltung, Uhr-Einblendung, Ken-Burns-Bewegung, Kurzbefehle. Informal
*du*, same as the UI.

### Subtitle (30 chars max)

    Deine Fotos, dein Rahmen

24/30 chars. Mirrors the English subtitle and stays source-neutral.

### Promotional text (170 chars max)

    Deine Fotos an der Wand: geteilten Immich-Link einfügen, und die Diashow
    läuft. Teile ein Album mit deinen Liebsten — aktualisierst du es, folgt
    ihr Rahmen von selbst.

167/170 chars.

### Description (4000 chars max)

```
OwnFrame macht aus einem iPad einen Bilderrahmen für deinen eigenen Immich-Server.

Egal ob du selbst einen Immich-Server betreibst oder dir jemand einen Albumlink geschickt hat: Diese App bringt das Album an die Wand. Sie spricht direkt über die REST-API mit dem Immich-Server. Es werden keine Daten gesammelt — alles bleibt bei dir.

IN UNTER EINER MINUTE EINGERICHTET
• Geteilten Immich-Link einfügen, und die Diashow startet. Ist der Link passwortgeschützt, wirst du danach gefragt — das war's.
• Oder verbinde dich mit Serveradresse und API-Schlüssel und wähle deine Alben in einer durchsuchbaren Liste.
• Du kannst einen Immich-Link auch direkt aus Safari oder einer anderen App teilen.

DIE DIASHOW
• Bildschirmfüllend, ein Foto nach dem anderen, mit Überblenden, Auflösen oder Schieben — alle Übergänge sind enthalten.
• Der Reihe nach oder gemischt, Anzeigedauer pro Foto, Einpassen oder Ausfüllen, Bildqualität — jede Einstellung wirkt sofort, ohne Neustart.
• Tippen öffnet die Steuerung: Pause, vor und zurück, ein Albumbrowser und eine Foto-Info-Einblendung (Datum und Ort).

FÜR DEN DAUERBETRIEB GEMACHT
• Hält den Bildschirm wach und lässt die Helligkeit dimmen, damit der Rahmen im Raum nicht stört.
• Läuft auf älteren iPads (ab iPadOS 17) — ein ausgemustertes iPad gibt einen guten Rahmen ab.

HOME ASSISTANT, WENN DU MAGST
• Verbinde den Rahmen mit deinem MQTT-Broker (TLS), und er erscheint von selbst in Home Assistant, ganz ohne Freischaltung: was gerade läuft, das aktuelle Foto mit Datum und Ort, die Fotoanzahl und ein Verfügbarkeitssensor.
• Das Foto selbst an den Broker zu senden, ist standardmäßig aus — freiwillig und ebenfalls enthalten.
• Den Rahmen aus Home Assistant heraus zu steuern, gehört zur Supporter-Freischaltung: Wiedergabe und Pause, Helligkeit, Albumauswahl, vor und zurück sowie jede Anzeigeeinstellung als steuerbare Entität — dazu Kurzbefehle und App-Intents.
• Über die HomeKit-Bridge von Home Assistant funktionieren diese Steuerungen auch in Apples Home-App und mit Siri.

WAS ENTHALTEN IST, WAS EINE FREISCHALTUNG ERGÄNZT
• Der Rahmen ist kostenlos und bleibt vollständig: jede Quelle (dein eigener Server, ein geteilter Link oder deine Fotos-Mediathek), die komplette Diashow mit allen Übergängen, Mischen, Anzeigedauer, Einpassen, Qualität, Helligkeit, Bildschirm-wach-halten, der Albumbrowser, die Foto-Info-Einblendung und die genannte Home-Assistant-Telemetrie.
• Eine optionale Supporter-Freischaltung ergänzt alles Weitere in einem einzigen einmaligen Kauf: Ken-Burns-Bewegung, die Uhr-Einblendung und die volle Home-Assistant-Steuerung — jede steuerbare Entität, Kurzbefehle und App-Intents.
• Ein einmaliger Kauf — niemals ein Abo. Die Familienfreigabe ist aktiv, und ein Kauf gilt für iPad, iPhone und Apple TV.
• Wohin dein Geld geht: Die Freischaltung deckt die laufenden Kosten des Projekts — Entwicklerkonto, KI-Werkzeuge, Testgeräte. Alles darüber hinaus fließt zurück an Open-Source-Projekte, die der Gemeinschaft dienen.

DATENSCHUTZ
• Die App spricht nur mit dem Server, den du einrichtest (und mit deinem MQTT-Broker, falls du einen einrichtest).
• API-Schlüssel, Passwörter für geteilte Links und Broker-Zugangsdaten liegen im Schlüsselbund des Geräts.
• Der Quellcode ist öffentlich (Fair Source; wird nach zwei Jahren MIT): github.com/kipp-ing/OwnFrame

EHRLICHE GRENZEN
• Du brauchst einen Immich-Server, der über HTTPS mit gültigem Zertifikat erreichbar ist — oder einen geteilten Link von einem solchen Server. Selbstsignierte Zertifikate werden noch nicht unterstützt.
• iOS erlaubt keiner App, das Display abzuschalten; die App dimmt den Bildschirm stattdessen. Wach-halten und Helligkeit wirken, solange die App im Vordergrund läuft — auf einem fest installierten Rahmen ist sie genau dort.
• Auf dem Apple TV gibt es die Uhr-Einblendung noch nicht; die Ken-Burns-Bewegung schon.

Dies ist eine unabhängige App. Sie steht in keiner Verbindung zu Immich oder FUTO und wird von ihnen nicht unterstützt.
```

3,982/4,000 chars — tighter headroom than the English text, because German
runs longer; trim here first if anything gets added.

### Keywords (100 chars max)

    immich,diashow,selfhosted,bilderrahmen,fotorahmen,server,wand,display,home assistant,mqtt,kiosk

95/100 chars. German search does not split compounds, so *bilderrahmen* and
*fotorahmen* have to be spelled out even though the subtitle carries "Fotos" and
"Rahmen". `immich` and `server` are here for the same reason as in English.

### What's New

    Erste Veröffentlichung.

## Categories & misc

- **Primary category**: Photo & Video. **Secondary**: Lifestyle.
- **Age rating**: 4+ (content comes from the user's own server).
- **Support URL**: https://github.com/kipp-ing/OwnFrame
- **Privacy nutrition label**: "Data Not Collected" (matches the privacy manifest — the app has
  no analytics and talks only to user-configured endpoints).

## App Review notes (paste into ASC → App Review Information → Notes)

Demo link: **https://bilder.kippings.de/s/Iceland2021** — password-free ALBUM share
("2021-06-Island best of", 38 images), expires 2027-07-11. Live-validated 2026-07-11 against
the exact client paths in build 1.0 (3). `demoAccountRequired` stays **false** — the shared
link *is* the demo access and reviewers need no account.

    This app is a slideshow client ("digital photo frame") for Immich, a popular
    open-source, self-hosted photo backup platform (https://immich.app). Reviewers
    do not need an Immich server or an account to test it: on the first onboarding
    screen choose "Shared link" and paste this demo link to a photo album:

    https://bilder.kippings.de/s/Iceland2021

    The slideshow starts immediately. Settings (transitions, timing, fit, quality,
    brightness, photo info overlay) are available from the gear button once the
    slideshow runs, and need no purchase.

    In-app purchases: the app is free and fully usable without any purchase — every
    photo source, the whole slideshow, and Home Assistant telemetry are included.
    A single one-time "Supporter Unlock" adds the optional extras: Ken Burns motion,
    the clock overlay, and controlling the frame from Home Assistant (plus Siri
    Shortcuts and App Intents). There are no subscriptions and no separate tiers. The
    tip jar grants no features at all. Locked settings rows are marked with a lock and
    open the unlock screen when tapped — the rest of the app never shows purchase UI,
    so the demo link above exercises the full free experience end to end.

    Naming: "OwnFrame" is a standalone brand name that contains no third-party
    trademark. The app is an independent client and states it is not affiliated
    with the Immich project.

## Internal notes (not for the listing)

- **Naming provenance**: the app was previously named "Photo Frame for Immich", which Alex
  (Immich creator) personally accepted in direct channel contact (2026-07-05). It was renamed
  to **"OwnFrame"** on 2026-07-22 — a standalone brand with no third-party trademark, so the
  guideline 5.2.1 (trademark) concern no longer applies. The public listing keeps the
  "independent app, not affiliated" line regardless.
- **Rename follow-through** — "OwnFrame" is the home-screen name, the share-sheet extension
  name, and the default HA device name. At 8 characters it fits the icon label with no
  truncation. The Xcode project, source folders, schemes, and the GitHub repo were also
  renamed to OwnFrame (2026-07-22); the bundle IDs (`ing.kipp.Immich-Slideshow`) are
  deliberately unchanged, so the App Store record, Keychain items, and app-group/entitlements
  are preserved.
  **Done in ASC (verified 2026-07-26)**: the app record name is "OwnFrame", and the descriptions
  and subtitles on the 1.1 version no longer open with "Photo Frame for Immich" in either locale.
  The 1.0 version record still carries the old text — deliberately left alone, since 1.0 is never
  released (FR-1100-17).
- **900 (photo-library source) has shipped** (merged 2026-07-18): the description already covers
  the Photos library, and the subtitle was made source-neutral on 2026-07-26 for the same reason.
- **What's New**: "Initial release." — no need to invent history. Note the version this
  ships under is **not** 1.0: approved build 1.0 (8) is deliberately never released, so the
  gated build is the first version the public ever sees (FR-1100-17). It still is an initial
  release from a user's point of view, so the copy stands; only the version number moves.
- **IAP metadata in ASC**: the single **Supporter Unlock** is non-consumable and MUST have
  Family Sharing enabled (FR-1100-06); the tips are consumable and not family-shared. (The
  earlier plan of two unlocks + a bundle was consolidated to one product on 2026-07-23.) Review
  notes for the IAP itself can point at the same demo link — no purchase is needed to reach the
  unlock screen, only to complete a purchase.
