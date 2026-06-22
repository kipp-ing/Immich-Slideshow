# Immich Slideshow

A full-screen photo **slideshow app for iPad**, powered by your own
[Immich](https://immich.app) server. It is a standalone app — **not** a fork of the
official Immich client — and uses Immich purely as a photo source over its REST API.

> ⚠️ **Active development.** Onboarding, the full-screen slideshow, display/power control,
> and Home Assistant remote control are built; theme/display options (transitions, Ken Burns,
> clock overlay) are the next milestone. Home Assistant control is verified against an
> automated TLS broker test — live Home-Assistant confirmation is still pending.

## What it does (and will do)

- **Onboarding** — connect to your server in three steps: server URL → API key → album. ✅ done
- **Slideshow** — full-screen, one photo at a time, with gentle cross-fades, reveal-on-tap
  controls, an album browser, and a photo-info overlay. ✅ done
- **Display & power** — keep the screen awake and dim brightness for ambient display. ✅ done
- **Home Assistant control** — adjust brightness, album, and play/pause over MQTT (TLS). ✅ done
- **Theme & display options** — transitions, Ken Burns, clock overlay, image fit. 🚧 planned

## Requirements

- An iPad running **iPadOS 18** or later.
- An **Immich server reachable over HTTPS with a valid TLS certificate.**
  (Self-signed / local certificates are not supported yet.)
- An Immich **API key** (Immich → Account Settings → API Keys). It is stored in the
  iOS **Keychain** — never in plain settings or logs.

## Getting started

1. Launch the app on your iPad.
2. Enter your Immich server address (HTTPS).
3. Paste your API key.
4. Pick an album to display.

That's it — the app remembers your setup and skips straight to the slideshow on the
next launch. You can reset everything from the main screen to start over.

## Privacy & security

- Your API key lives only in the device Keychain and is sent solely as the
  `x-api-key` header to **your** server.
- The app talks only to the Immich server you configure — no third parties.
- TLS is always validated; the app never disables certificate checks.

## For contributors

This project is built with Swift 6, SwiftUI, and Swift Package Manager, following a
spec-driven, test-first workflow.

- [docs/testing.md](docs/testing.md) — how the project is tested and how to run each layer.
- [docs/engineering-notes.md](docs/engineering-notes.md) — learnings, gotchas, and conventions.
- [CLAUDE.md](CLAUDE.md) — architecture, modules, constraints, and the working agreement.
