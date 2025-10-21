import csv
import requests
import os

URL = "https://api.weatherlink.com/v2/historic/205011"
PARAMS = {
    "api-key": "ysfvgjxvypxd5uq4kmojgqqoixmh3cdy",
    "start-timestamp": "1760914800",
    "end-timestamp": "1760918400",
}
HEADERS = {"x-api-secret": "allkoponohswxku4dtumss2ykudmul4r"}

TARGET_LSID = 813260
OUT_CSV = os.environ.get("OUT_CSV", "sensor_813260.csv")

resp = requests.get(URL, params=PARAMS, headers=HEADERS)
resp.raise_for_status()
payload = resp.json()

sensor = next((s for s in payload.get("sensors", []) if int(s.get("lsid", -1)) == TARGET_LSID), None)
if not sensor:
    raise SystemExit(f"Sensor with lsid {TARGET_LSID} not found")

rows = sensor.get("data", [])
if not rows:
    raise SystemExit(f"No data for sensor {TARGET_LSID}")

# collect all keys
keys = set()
for r in rows:
    keys.update(r.keys())
fieldnames = sorted(keys)

with open(OUT_CSV, "w", newline="", encoding="utf-8") as f:
    w = csv.DictWriter(f, fieldnames=fieldnames, extrasaction="ignore")
    w.writeheader()
    for r in rows:
        out = {k: ("" if r.get(k) is None else r.get(k)) for k in fieldnames}
        w.writerow(out)