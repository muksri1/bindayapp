# Troubleshooting — Raspberry Pi 3A+ / 512MB deployment

Real-world issues hit while deploying this kiosk on a Raspberry Pi 3 Model A+ (512MB) with Raspberry Pi OS (32-bit) Trixie, in the order they occurred. If your kiosk misbehaves, scan the symptoms below — every one of these was encountered and solved during the original build.

## Quick reference

| Symptom | Cause | Fix |
|---|---|---|
| No wireless interface at all | Stale/broken Wi-Fi firmware in old image, or dead radio | Re-flash with current image, fresh download; if still absent, warranty the board |
| Chromium RAM warning dialog blocks kiosk | Pi OS wrapper script checks for <1GB RAM | Launch `/usr/lib/chromium/chromium` directly, not `chromium` |
| "Choose password for new keyring" prompt | Chromium asks gnome-keyring on first run | Add `--password-store=basic` |
| `status=217/USER` in systemd | Service file references a user that doesn't exist | Match `User=` and paths to your actual username |
| White screen at boot, works when launched manually later | Chromium's network service crashes under startup memory pressure; tab never retries | 15s settle delay before launch + supervised restart (systemd user service) |
| Kiosk service never starts (bare desktop) | `graphical-session.target` never activates under labwc | Anchor user service to `default.target` + wait for wayland socket |
| Low voltage warning (top-right) | Weak PSU or thin micro-USB cable | 5V/2.5A supply; verify `vcgencmd get_throttled` → `0x0` |
| Chromium dies when SSH session closes | Manually launched process is a child of the SSH session | Only launch via the systemd user service; for manual tests use `setsid` |
| 64-bit OS: constant memory pressure | 64-bit userland ~doubles per-process memory on 512MB | Use 32-bit Raspberry Pi OS |

## The working architecture

Two supervised layers, deliberately separated:

**Layer 1 — servers (system service)**: `binday.service` runs the Flask proxy (:3001) and static file server (:8080). No GUI dependency; restarts on failure; up before the browser needs them.

**Layer 2 — browser (systemd *user* service)**: `kiosk.service` in `~/.config/systemd/user/` launches Chromium into the labwc/Wayland session. Key details that took real debugging to discover:

```ini
[Unit]
Description=BinDay Chromium Kiosk
After=default.target

[Service]
Environment=WAYLAND_DISPLAY=wayland-0
ExecStartPre=/bin/bash -c 'until [ -S /run/user/1000/wayland-0 ]; do sleep 2; done; until curl -s -o /dev/null http://localhost:8080; do sleep 2; done; sleep 15'
ExecStart=/usr/lib/chromium/chromium --ozone-platform=wayland --password-store=basic --kiosk --noerrdialogs --disable-infobars --no-first-run --disable-extensions --disable-background-networking --disable-component-update --disable-sync --disk-cache-size=1 --disable-gpu http://localhost:8080
Restart=on-failure
RestartSec=10

[Install]
WantedBy=default.target
```

Why each non-obvious piece exists:

- **`WantedBy=default.target`** — labwc on Pi OS never activates `graphical-session.target`, so a service anchored there waits forever. `default.target` always fires for a user session.
- **`ExecStartPre` triple wait** — wayland socket (compositor up) → HTTP 200 (server up) → 15s settle. The settle delay is not cosmetic: without it, Chromium initialises during peak boot memory pressure and its internal network service crashes (`Network service crashed or was terminated` in the log), leaving a permanently white tab because the load is never retried.
- **`/usr/lib/chromium/chromium`** — the `/usr/bin/chromium` wrapper pops a blocking "not recommended under 1GB RAM" dialog that kills unattended startup.
- **`--disable-gpu`** — the VideoCore IV + ANGLE/GLES path white-screens on this board. Software rendering is fine for a page that repaints a countdown once a second.
- **`--ozone-platform=wayland`** — explicit, so the service doesn't depend on session auto-detection.
- **`Restart=on-failure`** — the kiosk self-heals from any future Chromium crash.

## Debugging techniques that paid off

**Capture boot-time browser output** — add logging to whatever launches Chromium:

```bash
exec > /tmp/kiosk.log 2>&1; set -x; ...
```

The white-screen root cause was invisible until this log showed the network-service crash directly.

**Test the layers independently over SSH:**

```bash
systemctl status binday --no-pager               # servers up?
curl http://localhost:3001/health                 # proxy responding?
curl -s http://localhost:8080 | wc -c            # page intact? (~22 KB)
systemctl --user status kiosk --no-pager         # browser service state
systemctl --user is-active default.target        # did the anchor target fire?
vcgencmd get_throttled                            # 0x0 = power is clean
dmesg | grep -i "killed process"                 # OOM kills?
```

**Manual browser launch from SSH** (survives only while the session is open — diagnostic use only):

```bash
WAYLAND_DISPLAY=wayland-0 XDG_RUNTIME_DIR=/run/user/1000 \
  /usr/lib/chromium/chromium --ozone-platform=wayland --password-store=basic \
  --kiosk --disable-gpu http://localhost:8080
```

## Known open issue

The Blacktown Council API call through the proxy currently returns errors; the app runs on the manual schedule fallback (footer shows `manual schedule` instead of `council API`). The endpoint or response parser in `proxy.py` / `index.html` needs validating against a real API response:

```bash
curl -s "http://localhost:3001/waste?address=<your address>" | head -c 2000
```

## Screenshots

| | |
|---|---|
| ![Kiosk running](images/kiosk-running-setup-screen.jpg) | App running on the 7" panel (setup screen) |
| ![White screen](images/white-screen-issue.jpg) | The boot-time white screen — network service crash |
| ![RAM warning](images/chromium-ram-warning.jpg) | Wrapper's RAM dialog that blocks kiosk startup |
| ![Keyring + voltage](images/keyring-prompt-low-voltage.jpg) | Keyring prompt and low-voltage warning |
