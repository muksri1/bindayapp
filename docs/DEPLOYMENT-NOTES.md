# Raspberry Pi Zero 2W — deployment notes & verification (v2)

The hard-won, known-good setup for running this kiosk on a **Pi Zero 2W (512 MB RAM)**
with a Bookworm-based Raspberry Pi OS image. Read this if the display misbehaves —
every item here fixed a real problem during v2 bring-up.

## The environment that actually works

- **Display server: X11**, not Wayland. The "Legacy" image can still boot the
  Wayland (labwc/wayfire) compositor, where cursor-hiding and `DISPLAY=:0` kiosk
  launching don't behave. Switch with `sudo raspi-config` → Advanced Options →
  Wayland → **W1 X11**, then reboot. Verify: `pgrep -a Xorg` prints a process.
- **Browser binary: `chromium`** (Bookworm), not `chromium-browser`. `start.sh`
  auto-detects either.
- **Autostart via the desktop session**, not systemd. GUI kiosks are far more
  reliable when launched from the logged-in desktop session (correct `DISPLAY`/
  `XAUTHORITY`, no boot-order race, no `sudo`). systemd is left disabled.

## What's configured on the Pi

1. **App autostart** — `~/.config/autostart/binday.desktop`:
   ```ini
   [Desktop Entry]
   Type=Application
   Name=BinDay
   Exec=/bin/bash /home/muksri/blacktown-bin-day/start.sh
   X-GNOME-Autostart-enabled=true
   ```
2. **Cursor hide** — `~/.config/autostart/unclutter.desktop` (X11 only):
   ```ini
   [Desktop Entry]
   Type=Application
   Name=unclutter
   Exec=unclutter -idle 0 -root
   ```
   Installed with `sudo apt install -y unclutter`. `start.sh` also launches it.
3. **Swap = 1 GB** — the image had no `dphys-swapfile`; installed and sized it so
   Chromium doesn't OOM on 512 MB:
   ```bash
   sudo apt install -y dphys-swapfile
   sudo dphys-swapfile swapoff
   sudo sed -i 's/^#\?CONF_SWAPSIZE=.*/CONF_SWAPSIZE=1024/' /etc/dphys-swapfile
   sudo dphys-swapfile setup && sudo dphys-swapfile swapon
   ```
4. **GPU memory split lowered** — `gpu_mem=64` in `/boot/firmware/config.txt`
   frees RAM for the browser.
5. **Screen blanking off** — `sudo raspi-config nonint do_blanking 1`.
6. **`xdotool` installed** — `sudo apt install -y xdotool`, used by `start.sh` to
   force a reload after launch (see below).

## The Chromium flags that matter (all in `start.sh`)

- `--no-memcheck` — skips the Raspberry Pi wrapper's *"not recommended to run
  Chromium on devices with less than 1 GB of RAM"* dialog, which otherwise blocks
  the whole screen and has no keyboard to dismiss it. This is the wrapper's own
  supported flag; it's consumed by `/usr/bin/chromium` and never reaches Chromium.
- `--password-store=basic` — stops Chromium popping the GNOME **"Choose password
  for new keyring"** dialog on first launch. The app stores nothing sensitive.
- `--kiosk --test-type --hide-scrollbars --noerrdialogs` etc. — fullscreen, no
  infobars, no scrollbars.
- Low-memory set: `--disable-dev-shm-usage --disable-extensions
  --disable-background-networking --renderer-process-limit=1 --process-per-site
  --disable-features=Translate,BackForwardCache`.

## The cold-boot white-screen fix

On a cold boot Chromium can open `localhost:8080` a moment before the local Python
server is ready (→ white "connection refused" page), or paint blank before the
compositor is up. `start.sh` handles both:

1. **Readiness wait** — loops `curl` against the app port and only launches
   Chromium once the server answers.
2. **Reload safety net** — after launch it sends `xdotool key F5` a few times over
   the first ~40 s, so any blank/early state self-heals once everything is up.
   Reloads are invisible if the app is already showing.

## Verification checklist

Run after any change or reboot. SSH in as `muksri@binday.local`.

**Environment**
```bash
pgrep -a Xorg && echo "X11 OK"          # must print a process
which chromium chromium-browser         # expect /usr/bin/chromium
free -h                                  # Swap total ~1.3 Gi (dphys + zram)
```

**App is serving & running**
```bash
curl -s localhost:8080 | grep -o '<title>.*</title>'   # Bin Day — Blacktown Council
ss -ltnp 2>/dev/null | grep -E '3001|8080'             # both listening
pgrep -a chromium | head -1                            # chromium running
```

**On-screen behaviour**
- Boots straight into the kiosk with **no cursor**, **no scrollbar**, **no dialogs**.
- Countdown shows days to the **next Tuesday** (not a stuck "0 days").
- Reboot 2–3 times — the bins should appear every time (no white screen).

**Time-based behaviour (fake the clock to test without waiting):**
```bash
sudo timedatectl set-ntp false
sudo date -s "2026-08-03 18:05:00"   # Monday 6:05 PM → put-out bins should PULSE
# ...check screen...
sudo date -s "2026-08-04 15:00:00"   # Tuesday afternoon → cycle rolls to next week, no restart
# ...check screen...
sudo timedatectl set-ntp true        # restore real time
```

**If it goes white on a boot**, capture evidence from that boot before rebooting:
```bash
cat /tmp/binday.log
curl -s localhost:8080 | head -c 100      # server up?
pgrep -a chromium
```

## Quick reference — restart / redeploy on the Pi

```bash
# restart the kiosk without rebooting
pkill -f start.sh; pkill chromium; pkill -f proxy.py; pkill -f "http.server 8080"
sleep 2
DISPLAY=:0 XAUTHORITY=$HOME/.Xauthority nohup ~/blacktown-bin-day/start.sh >/tmp/binday.log 2>&1 &
```

The Pi folder is a plain file copy (not a git checkout). Update it with `pscp`
from your PC, or `git clone` the repo over it once so future updates are `git pull`.
See `DEPLOY.md`.
