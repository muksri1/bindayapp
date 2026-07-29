# Installation guide — Raspberry Pi Zero 2W

Step-by-step deployment of the bin day display on a Pi Zero 2W with an HDMI display.

## 1. Flash the SD card

1. Download [Raspberry Pi Imager](https://www.raspberrypi.com/software/)
2. OS: **Raspberry Pi OS (Legacy, 32-bit) with Desktop** — the Zero 2W has 512MB RAM; Desktop is required for Chromium kiosk mode
3. Click the gear icon (Edit Settings) before writing:
   - Hostname: `binday`
   - Enable SSH (password authentication)
   - Set username and password
   - Configure Wi-Fi (SSID, password, country `AU`)
   - Timezone: `Australia/Sydney`
4. Write the image and insert the card into the Pi

## 2. First boot

1. Connect the display (mini-HDMI adapter) and power (micro-USB port labelled PWR — the outer port)
2. Allow ~2 minutes for first boot
3. SSH in from another machine:

```bash
ssh muksri@binday.local
```

## 3. Install the app

```bash
sudo apt update && sudo apt install -y python3-flask python3-requests git
git clone https://github.com/<your-username>/blacktown-bin-day.git
cd blacktown-bin-day
chmod +x start.sh
```

Smoke test:

```bash
./start.sh
```

The setup screen appears on the display. Enter your **collection day** and a **recent Yellow bin date** once (persists in localStorage). Ctrl+C to stop.

## 4. Autostart on boot

Option A — systemd:

```bash
sudo cp binday.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now binday
```

Option B — LXDE autostart (more reliable for GUI apps on Pi OS Legacy):

```bash
mkdir -p ~/.config/autostart
cat > ~/.config/autostart/binday.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=BinDay
Exec=/bin/bash /home/muksri/blacktown-bin-day/start.sh
EOF
```

Use one method only. If systemd shows a blank screen (Chromium starting before the desktop session), switch to Option B.

## 5. Kiosk hardening — hide cursor & scrollbar (issue #3)

**v2 already hides the scrollbar and mouse cursor from inside the app** (CSS `cursor:none`, hidden scrollbars) and passes `--hide-scrollbars` to Chromium via `start.sh`. That covers most cases on its own.

For a belt-and-braces cursor hide at the OS level, add the right tool for your Pi OS version:

**X11 (Pi OS Legacy / Bullseye, or Bookworm with "Wayland: off"):**

```bash
sudo apt install -y unclutter-xfixes
# start.sh already launches unclutter; to also hide it at desktop login:
mkdir -p ~/.config/autostart
cat > ~/.config/autostart/unclutter.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=unclutter
Exec=unclutter --timeout 1 --jitter 2 -b
EOF
```

> The v1 instruction to edit `~/.config/lxsession/LXDE-pi/autostart` only works on the old LXDE session and silently does nothing on current images. Use the `~/.config/autostart/*.desktop` method above instead.

**Wayland (Pi OS Bookworm default — `labwc` or `wayfire`):**

`unclutter` does not work under Wayland. Hide the cursor in the compositor instead:

- **labwc** (default on Bookworm): edit `~/.config/labwc/rc.xml`, inside `<core>` add
  `<cursor><hideOnKeyPress>no</hideOnKeyPress></cursor>` and install `wlopm`/`swayidle`,
  or simplest: the in-app `cursor:none` already hides it while the pointer is over the page (the whole screen in kiosk). Nudge the mouse off-screen once after boot.
- **wayfire**: add to `~/.config/wayfire.ini`:

  ```ini
  [idle]
  cursor_timeout = 1
  ```

Then disable screen blanking so the display stays on:

```bash
sudo raspi-config nonint do_blanking 1
```

Optional nightly reboot (no longer required for correctness in v2 — see note below — but harmless):

```bash
(crontab -l 2>/dev/null; echo "0 3 * * * /sbin/shutdown -r now") | crontab -
```

## 6. Mount and verify

1. Attach the Pi to the back of the display (velcro / 3M tape), mount near the garage or front door
2. `sudo reboot` — confirm it boots straight into the kiosk display
3. Verify Monday evening shows the correct bins **pulsing** (5 PM onward), and that after Tuesday's pickup the display rolls to the next cycle on its own — **no restart needed** (issue #2 fixed in v2)

## Troubleshooting

| Symptom | Fix |
|---|---|
| Blank screen after boot | `systemctl status binday`; switch to LXDE autostart (Option B) |
| "No signal" on display | Add `hdmi_force_hotplug=1` to `/boot/config.txt` (or `/boot/firmware/config.txt` on Bookworm) |
| Wrong bins / wrong week | Open the app, click **Change address**, and re-enter a known Yellow bin date. The fortnightly cycle is anchored to that date. |
| Cursor still visible (Wayland) | Nudge the mouse to a screen corner once; confirm you're on X11 if you want `unclutter`. See §5. |
| Countdown looked stuck before v2 | Fixed — v2 derives the schedule live each second, so it can no longer freeze on a past collection date. |
| Wi-Fi drops overnight | Disable Wi-Fi power management: `sudo iwconfig wlan0 power off` (persist via `/etc/rc.local`) |

> **Note on nightly reboot:** v1 relied on a restart to refresh the frozen schedule. v2 no longer needs this — the cron reboot in §5 is now optional housekeeping only.
