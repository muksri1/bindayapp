[README.md](https://github.com/user-attachments/files/29878373/README.md)
# Blacktown Bin Day Display

A minimal kiosk web app for Blacktown Council (NSW) residents. Shows which bins to put out on Monday evenings — pulling live collection schedules directly from the Council's waste services API so the fortnightly Yellow bin cycle is always accurate, for any address in the LGA.

Built to run on a Raspberry Pi Zero 2W with a small HDMI display mounted near the front door or in the garage.

![Demo: Monday view showing Red, Green, and Yellow bins](docs/screenshot-monday.png)

## How it works

- On **Mondays**, the display shows exactly which bins to leave on the kerb that night, with clear visual status for each bin.
- On **other days**, it shows when the next collection is and which bins will be needed.
- Address is saved to `localStorage` — enter it once, never again.
- A lightweight Flask proxy handles CORS when calling the Council API. Falls back to local fortnightly calculation if the proxy isn't reachable.

## Generalised for any Blacktown address

Enter any street address in the Blacktown LGA and the app queries the Council's API for that property's actual scheduled collection dates — no hardcoded suburb logic.

## Project structure

```
blacktown-bin-day/
├── src/
│   └── index.html      # Single-file frontend app
├── proxy.py            # Flask CORS proxy (runs on Pi alongside app)
├── start.sh            # Launches proxy + static server + Chromium kiosk
├── binday.service      # systemd unit for autostart on Pi boot
└── README.md
```

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

## Setup

### 1. Install dependencies

```bash
pip3 install flask requests
```

### 2. Clone and configure

```bash
git clone https://github.com/<your-username>/blacktown-bin-day.git
cd blacktown-bin-day
chmod +x start.sh
```

### 3. Run locally (any machine)

```bash
python3 proxy.py &
python3 -m http.server 8080 --directory src/
# Open http://localhost:8080 in browser
```

### 4. Deploy on Pi (autostart)

```bash
sudo cp binday.service /etc/systemd/system/
sudo systemctl enable binday
sudo systemctl start binday
```

The service starts on boot, launches the proxy and static server, then opens Chromium in kiosk mode.

### 5. Enter your address

On first load, enter your street address and house number. The app queries the Blacktown Council API and saves the result locally. No data leaves your network.

## Fortnightly fallback

If the proxy isn't running (or the Council API is unreachable), the app falls back to a locally-computed fortnightly cycle anchored to a known Yellow bin Tuesday (`2025-01-07`). Update `YELLOW_REF` in `index.html` if this reference date ever becomes stale.

## Sharing with neighbours

Each user enters their own address on first load. The app works for any property in the Blacktown LGA — just share the repo or host the `src/` folder on a local network.

## Licence

MIT
