# Changelog

## v2.0.0 — 2026-07-29

Second release. Fixes the four issues found after running v1 in production for a
few weeks.

### Fixed
- **Stale display after Tuesday pickup (no more Pi restart).** v1 computed a
  single `nextCollection` date once at load and then ticked against that frozen
  value. After a pickup it pointed at a past date, so the display stuck on
  "0 days / bins out last night" (and sometimes showed all three bins for the
  wrong week) until the Pi was rebooted. v2 removes the cached date entirely and
  **derives the whole schedule from the current time on every 1-second tick**, so
  it advances to the next cycle automatically after ~2 PM on collection day.

### Added
- **Monday-evening put-out reminder (5 PM – midnight).** The bins you need to
  leave out gently pulse and glow on the night before collection, with an amber
  "Put these bins out now" prompt. Purely visual, tuned to be attention-grabbing
  without being harsh in a dark room.

### Changed
- **On-device fortnightly calculation is now the primary source of truth.**
  Investigation confirmed Blacktown Council has **no public bin-day API** — the
  council page uses a client-side widget, and the endpoint v1's proxy targeted
  (`/api/v1/myblacktown/waste-services`) is not real and returns nothing. The
  app now relies on the local calculation (collection day + a known Yellow bin
  date) and treats the proxy as optional best-effort only.
- **Kiosk cleanup.** Mouse cursor and scrollbars are hidden in-app
  (`cursor:none`, hidden scrollbars); `start.sh` adds Chromium `--hide-scrollbars`
  and launches `unclutter`. `docs/INSTALL.md` now has correct cursor-hiding steps
  for both X11 and Wayland (Bookworm) — the old `~/.config/lxsession/...` path
  silently did nothing on current images.
- Setup screen reworked around collection day + Yellow bin date (the values the
  local calculation actually needs). Existing saved settings are preserved.

### Deployment hardening (Pi Zero 2W / Bookworm)
Bring-up on a 512 MB Pi Zero 2W surfaced several environment issues, all now
solved and documented in `docs/DEPLOYMENT-NOTES.md`:
- Switched the Pi from **Wayland to X11** (`raspi-config`) so cursor-hiding and
  `DISPLAY=:0` kiosk launching behave.
- `start.sh` **auto-detects `chromium` vs `chromium-browser`** (Bookworm renamed
  the binary) and sets `DISPLAY`.
- Added **`--no-memcheck`** (skips the RPi "<1 GB RAM" wrapper dialog) and
  **`--password-store=basic`** (skips the GNOME keyring prompt) — both otherwise
  block the kiosk with an undismissable dialog.
- **Autostart via the desktop session** (`~/.config/autostart/binday.desktop`)
  instead of systemd — reliable `DISPLAY`/`XAUTHORITY`, no boot-order race.
- **1 GB swap** (`dphys-swapfile`) + `gpu_mem=64` + low-memory Chromium flags so
  Chromium doesn't OOM-crash on 512 MB.
- **Cold-boot white-screen fix** in `start.sh`: wait for the app server to answer
  before launching Chromium, plus `xdotool` reloads over the first ~40 s so a
  blank first paint self-heals.

### Notes
- The nightly 3 AM cron reboot is now optional housekeeping, not a correctness
  requirement.
- `docs/DEPLOY.md`: how to push updates to the Pi via GitHub, VS Code local
  (Remote-SSH), or PuTTY/SCP. `docs/DEPLOYMENT-NOTES.md`: the full Pi Zero 2W
  working setup + verification checklist.

### Suggested commit message
```
v2.0.0: live schedule, put-out flashing, kiosk cleanup, local-first calc

- Fix stale display after pickup by deriving schedule live each tick (#2)
- Add 5 PM–midnight pulsing put-out reminder (#1)
- Hide cursor + scrollbars in kiosk; fix cursor steps for X11/Wayland (#3)
- Make on-device fortnightly calc the source of truth; confirm no public
  Blacktown API; proxy now optional (#4)
- Docs: rewrite INSTALL kiosk section, add DEPLOY guide, add CHANGELOG
```
