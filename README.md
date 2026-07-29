# Blacktown Bin Day Display

A minimal kiosk web app for Blacktown Council (NSW) residents. Shows which bins to put out on Monday evenings and counts down to the next Tuesday pickup — running on a Raspberry Pi with a small HDMI display mounted near the front door or garage.

![Demo: Monday view showing Red, Green, and Yellow bins](docs/screenshot-monday.png)

## What's new in v2

- **Put-out reminder that pulses.** On the night before collection, from **5:00 PM to midnight**, the bins you need to leave out gently pulse and glow so you don't forget (or put the wrong ones out).
- **No more restarts.** v1 froze a single "next collection" date at load, which went stale after each Tuesday pickup and needed a Pi reboot to fix. v2 **derives the schedule live every second from the current time**, so it rolls to the next cycle on its own and can never freeze on a past date.
- **On-device fortnightly calculation is now the source of truth.** Blacktown does not publish a public bin-day API (see below), so the app computes the Red/Green/Yellow cycle locally from your collection day plus a known Yellow bin date. No network needed once configured.
- **Cleaner kiosk.** The mouse cursor and scrollbars are hidden from inside the app, plus `--hide-scrollbars` on Chromium and updated cursor-hiding steps for both X11 and Wayland (Bookworm).

## How it works

- The app stores two things: your **collection day** (e.g. Tuesday) and a **recent date the Yellow bin was collected**. From those it computes the fortnightly cycle entirely on-device.
- **Night before collection:** shows the exact bins to leave on the kerb, pulsing from 5 PM.
- **Collection morning:** shows a "Collection day" message until early afternoon.
- **After ~2 PM on collection day:** automatically advances to next week's cycle.
- An optional Flask proxy (`proxy.py`) can cross-check against a council API if one ever becomes available — but it is never required.

## A note on the Blacktown API

Blacktown City Council's [Bin collection days](https://www.blacktown.nsw.gov.au/Services/Waste-services-and-collection/Bin-collection-days) page uses a **client-side address widget** and does **not** expose a documented public JSON API. The endpoint the v1 proxy pointed at (`/api/v1/myblacktown/waste-services`) is not a real council endpoint and returns nothing — which is why v1 was silently running on its local fallback all along. v2 makes that local calculation the intended, reliable source. If you ever confirm a real endpoint, set `COUNCIL_API` in `proxy.py` and the app will pick it up automatically.

Council-published fallbacks if you want to sanity-check your cycle: the printable **Area 1 / Area 2 2026 recycling calendars** (PDF) linked on the council page.

## Hardware

| Item | Source | ~Cost AUD |
|---|---|---|
| Raspberry Pi Zero 2W | Core Electronics / Little Bird | $29 |
| MicroSD card 16GB+ | Amazon AU | $8 |
| 7" HDMI display (800×480) | AliExpress | $35 |
| Mini HDMI adapter | AliExpress | $2 |
| Micro-USB power cable | AliExpress | $2 |
| **Total** | | **~$76** |

> Already have a spare tablet or monitor? Just point a browser at the Pi's IP — you only need the Pi + SD card (~$37).

## Project structure

```
blacktown-bin-day/
├── src/
│   └── index.html      # Single-file frontend app (all logic lives here)
├── proxy.py            # Optional Flask CORS proxy (not required)
├── start.sh            # Launches proxy + static server + Chromium kiosk
├── binday.service      # systemd unit for autostart on Pi boot
├── docs/
│   ├── INSTALL.md      # Pi setup + kiosk hardening
│   └── DEPLOY.md       # Pushing updates to the Pi (GitHub / VS Code / PuTTY)
├── CHANGELOG.md
└── README.md
```

## Quick start (any machine)

```bash
python3 -m http.server 8080 --directory src/
# open http://localhost:8080, enter collection day + a recent Yellow bin date
```

## Deploy on the Pi

See [docs/INSTALL.md](docs/INSTALL.md) for first-time setup and [docs/DEPLOY.md](docs/DEPLOY.md) for pushing updates (GitHub, VS Code local, or PuTTY/SSH).

## Licence

MIT
