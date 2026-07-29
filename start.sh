#!/bin/bash
# start.sh — Launch the bin day app on Raspberry Pi (v2)
# Starts the optional CORS proxy, serves the static app, and opens Chromium
# in kiosk mode with scrollbars and cursor hidden (issue #3).

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PORT_APP=8080
PORT_PROXY=3001

# Fall back to :0 if launched without a display env (e.g. from systemd on X11).
export DISPLAY="${DISPLAY:-:0}"

# The kiosk browser is called `chromium` on Bookworm and `chromium-browser` on
# older images. Use whichever exists.
CHROME_BIN="$(command -v chromium-browser || command -v chromium || true)"
if [ -z "$CHROME_BIN" ]; then
  echo "ERROR: no chromium binary found (tried chromium-browser, chromium)." >&2
  echo "Install it with: sudo apt install -y chromium" >&2
  exit 1
fi

# Free the ports if a previous instance is still holding them. Prevents the
# "Address already in use" collision and a duplicate Chromium that would OOM a
# 512MB Pi Zero 2W.
pkill -f "$SCRIPT_DIR/proxy.py" 2>/dev/null || true
pkill -f "http.server $PORT_APP" 2>/dev/null || true
pkill -f "$CHROME_BIN.*localhost:$PORT_APP" 2>/dev/null || true
sleep 1

echo "Starting CORS proxy on :$PORT_PROXY (optional)…"
python3 "$SCRIPT_DIR/proxy.py" &
PROXY_PID=$!

echo "Serving app on :$PORT_APP…"
python3 -m http.server $PORT_APP --directory "$SCRIPT_DIR/src" &
APP_PID=$!

sleep 2

# Hide the mouse cursor at the X11 level as well as in-app (belt and braces).
# unclutter-xfixes works on a running X session; harmless if already hidden.
if command -v unclutter >/dev/null 2>&1; then
  unclutter --timeout 1 --jitter 2 -b >/dev/null 2>&1 || unclutter -idle 1 >/dev/null 2>&1 &
fi

echo "Opening Chromium ($CHROME_BIN) in kiosk mode…"
"$CHROME_BIN" \
  --no-memcheck \
  --password-store=basic \
  --kiosk \
  --test-type \
  --hide-scrollbars \
  --noerrdialogs \
  --disable-infobars \
  --disable-session-crashed-bubble \
  --disable-pinch \
  --overscroll-history-navigation=0 \
  --no-first-run \
  --disable-translate \
  --check-for-update-interval=31536000 \
  --disable-dev-shm-usage \
  --disable-extensions \
  --disable-background-networking \
  --renderer-process-limit=1 \
  --process-per-site \
  --disable-features=Translate,BackForwardCache \
  "http://localhost:$PORT_APP" &

trap "kill $PROXY_PID $APP_PID 2>/dev/null" EXIT
wait
