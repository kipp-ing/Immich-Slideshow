# App Store Listing — Photo Frame for Immich

Copy-paste source for App Store Connect. Plain, factual tone on purpose — the audience is
self-hosters; they distrust marketing language. Field limits noted per section.

## Name (30 chars max)

    Photo Frame for Immich

22/30 chars.

## Subtitle (30 chars max)

    Slideshow for your own server or a shared album. Ultra simple setup.

29/30 chars.

## Promotional text (170 chars max, changeable without review)

    Your photos on the wall: paste an Immich shared link and the slideshow
    starts. Share an album with your loved ones — when you update it, their
    frame follows. Supports ios17, give your old iPad from 2017 a 2nd life.

157/170 chars.

## Description (4000 chars max)

```
Photo Frame for Immich turns an iPad into a photo frame for your own Immich server.

Whether you run your own Immich server or someone shared an album link with you: this app puts that album on the wall. It talks directly to the Immich server over its REST API. No data is collected — it's all yours.

SET UP IN UNDER A MINUTE
• Paste an Immich shared link and the slideshow starts. If the link has a password, you're asked for it — that's it.
• Or connect with your server URL and an API key to browse your albums in a searchable picker.
• You can also share an Immich link straight into the app from Safari or another app.

THE SLIDESHOW
• Full screen, one photo at a time, with cross-fades or other transitions and optional Ken Burns motion.
• Sequential or shuffle, per-photo duration, fit or fill, image quality — every option applies live, no restart.
• Tap for controls: pause, previous/next, an album browser, and a photo info overlay (date and location).

MADE TO RUN ALL DAY
• Keeps the screen awake and lets you dim the brightness for ambient use.
• Runs on older iPads (iPadOS 17 and up) — a retired iPad makes a good frame.

HOME ASSISTANT, IF YOU WANT IT
• Optional MQTT (TLS) with Home Assistant discovery: play/pause, brightness, album selection, next/previous, every display setting, current-photo metadata, and diagnostics appear as entities.
• Through Home Assistant's HomeKit Bridge those controls also work from the Apple Home app and Siri.
• Publishing the photo image itself to your broker is off by default — strictly opt-in.

PRIVACY
• The app talks only to the server you configure (and your MQTT broker, if you set one up). 
• API keys, shared-link passwords, and broker credentials are stored in the device keychain.
• Open source (MIT): github.com/kipp-ing/Immich-Slideshow

HONEST LIMITS
• You need an Immich server reachable over HTTPS with a valid certificate — or a shared link from one. Self-signed certificates aren't supported yet.
• iOS doesn't let apps switch the display off; the app dims the screen instead. Keep-awake and brightness control work while the app is in the foreground — on a dedicated frame that's exactly where it lives.

This is an independent app. It is not affiliated with or endorsed by Immich or FUTO.
```

~2,300/4,000 chars.

## Keywords (100 chars max)

    slideshow,self-hosted,digital,wall,display,home assistant,mqtt,album,kiosk,ambient,selfhosted

93/100 chars. Words already in the name/subtitle (photo, frame, immich, server) are indexed
automatically — don't waste keyword characters repeating them.

## Categories & misc

- **Primary category**: Photo & Video. **Secondary**: Lifestyle.
- **Age rating**: 4+ (content comes from the user's own server).
- **Support URL**: https://github.com/kipp-ing/Immich-Slideshow
- **Privacy nutrition label**: "Data Not Collected" (matches the privacy manifest — the app has
  no analytics and talks only to user-configured endpoints).

## Internal notes (not for the listing)

- **Naming provenance**: the name pattern "Photo Frame for Immich" was accepted by Alex
  (Immich creator) in direct channel contact, 2026-07-05. If App Review asks about trademark
  rights (guideline 5.2.1), reference that exchange. The public listing still carries the
  "independent app, not affiliated" line — that's the correct posture regardless.
- **Rename follow-through** — done 2026-07-09: README title, ASC app name, and the display
  name. The **home-screen name is "Photo Frame"** (not the full 22-char name), because iOS
  truncates icon labels around ~13 characters — "Photo Frame f…" would look broken. The full
  name lives in the App Store listing; the share-sheet extension and the HA device name also
  say "Photo Frame". The Xcode project/repo name stays as-is; it's not user-visible.
- **When 900 (photo-library source) ships**: subtitle becomes
  `Photo Frame for Immich & iCloud` (30/30 chars) and the description gets an Apple
  Photos/iCloud albums section.
- **What's New (v1.0)**: "Initial release." — no need to invent history.
