"""
proxy.py — Optional local CORS proxy for a Blacktown Council waste API.

NOTE (v2): Blacktown City Council does not currently publish a documented
public JSON API for bin collection days — the council website uses a
client-side address widget only. The endpoint below is therefore a
best-effort placeholder. The app works fully WITHOUT this proxy: it derives
the fortnightly schedule on-device from the collection day + a known Yellow
bin date. If a real endpoint becomes available, set COUNCIL_API and the app
will use it automatically to cross-check the schedule.

Usage:
    pip install flask requests
    python3 proxy.py            # listens on http://localhost:3001
"""

from flask import Flask, request, jsonify
import requests

app = Flask(__name__)

# Placeholder — no public Blacktown API is documented as of 2026. Leave as-is;
# the app falls back to the on-device calculation if this returns nothing.
COUNCIL_API = "https://www.blacktown.nsw.gov.au/api/v1/myblacktown/waste-services"


@app.after_request
def add_cors(response):
    response.headers["Access-Control-Allow-Origin"] = "*"
    response.headers["Access-Control-Allow-Headers"] = "Content-Type"
    return response


@app.route("/waste")
def waste():
    address = request.args.get("address", "").strip()
    if not address:
        return jsonify({"error": "address parameter required"}), 400
    try:
        resp = requests.get(COUNCIL_API, params={"address": address}, timeout=8)
        resp.raise_for_status()
        return jsonify(resp.json())
    except requests.exceptions.ConnectionError:
        return jsonify({"error": "Could not reach council API", "collections": []}), 502
    except requests.exceptions.Timeout:
        return jsonify({"error": "Council API timed out", "collections": []}), 504
    except requests.exceptions.HTTPError as e:
        return jsonify({"error": f"Council API returned {e.response.status_code}", "collections": []}), 502
    except ValueError:
        # Non-JSON response (e.g. an HTML page) — treat as "no data".
        return jsonify({"error": "Council API did not return JSON", "collections": []}), 502


@app.route("/health")
def health():
    return jsonify({"status": "ok"})


if __name__ == "__main__":
    print("Bin day proxy running on http://localhost:3001 (optional)")
    app.run(host="127.0.0.1", port=3001)
