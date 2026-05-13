#!/usr/bin/env python3

from pathlib import Path
from PIL import Image, ImageDraw
import math
import urllib.request
import urllib.error

# TileServer-GL PNG-Endpunkt
BASE_URL = "http://localhost:8080/styles/wammsee/{z}/{x}/{y}.png"

# Bounds aus deiner PMTiles-Datei:
# west, south, east, north
BOUNDS = (8.42, 49.325, 8.475, 49.36)

# Für "alle" relevanten Zooms bis maxzoom 14
MIN_ZOOM = 0
MAX_ZOOM = 14

OUT_DIR = Path("rendered_tiles")
DEBUG_DIR = Path("debug_mosaics")
TILE_SIZE = 256


def lonlat_to_tile(lon: float, lat: float, z: int) -> tuple[int, int]:
    lat_rad = math.radians(lat)
    n = 2 ** z

    x = int((lon + 180.0) / 360.0 * n)

    y = int(
        (1.0 - math.asinh(math.tan(lat_rad)) / math.pi)
        / 2.0
        * n
    )

    return x, y


def tile_range_for_bounds(bounds, z: int):
    west, south, east, north = bounds

    x_min, y_min = lonlat_to_tile(west, north, z)
    x_max, y_max = lonlat_to_tile(east, south, z)

    if x_min > x_max:
        x_min, x_max = x_max, x_min

    if y_min > y_max:
        y_min, y_max = y_max, y_min

    return x_min, x_max, y_min, y_max


def download_tile(z: int, x: int, y: int) -> bool:
    url = BASE_URL.format(z=z, x=x, y=y)
    target = OUT_DIR / str(z) / str(x) / f"{y}.png"
    target.parent.mkdir(parents=True, exist_ok=True)

    req = urllib.request.Request(
        url,
        headers={"User-Agent": "wammsee-tile-downloader/1.0"}
    )

    try:
        with urllib.request.urlopen(req, timeout=20) as response:
            status = response.status
            data = response.read()

        if status != 200:
            print(f"WARN {z}/{x}/{y}: HTTP {status}")
            return False

        if not data.startswith(b"\x89PNG\r\n\x1a\n"):
            print(f"WARN {z}/{x}/{y}: Antwort ist kein PNG")
            target.with_suffix(".bin").write_bytes(data)
            return False

        target.write_bytes(data)
        print(f"OK   {z}/{x}/{y} -> {target}")
        return True

    except urllib.error.HTTPError as e:
        print(f"MISS {z}/{x}/{y}: HTTP {e.code}")
        return False
    except Exception as e:
        print(f"ERR  {z}/{x}/{y}: {e}")
        return False


def make_debug_mosaic(z: int, x_min: int, x_max: int, y_min: int, y_max: int):
    xs = list(range(x_min, x_max + 1))
    ys = list(range(y_min, y_max + 1))

    width = len(xs) * TILE_SIZE
    height = len(ys) * TILE_SIZE

    out = Image.new("RGB", (width, height), "white")
    draw = ImageDraw.Draw(out)

    for row, y in enumerate(ys):
        for col, x in enumerate(xs):
            px = col * TILE_SIZE
            py = row * TILE_SIZE

            path = OUT_DIR / str(z) / str(x) / f"{y}.png"

            if path.exists():
                img = Image.open(path).convert("RGB").resize((TILE_SIZE, TILE_SIZE))
            else:
                img = Image.new("RGB", (TILE_SIZE, TILE_SIZE), "gray")

            out.paste(img, (px, py))

            # roter Tile-Rand
            draw.rectangle(
                [px, py, px + TILE_SIZE - 1, py + TILE_SIZE - 1],
                outline="red",
                width=2,
            )

            # Label-Hintergrund
            draw.rectangle(
                [px + 4, py + 4, px + 140, py + 28],
                fill="white",
            )

            # z/x/y Label
            draw.text(
                (px + 8, py + 8),
                f"{z}/{x}/{y}",
                fill="black",
            )

    DEBUG_DIR.mkdir(parents=True, exist_ok=True)
    out_path = DEBUG_DIR / f"wammsee_z{z}_x{x_min}-{x_max}_y{y_min}-{y_max}.png"
    out.save(out_path)
    print(f"DEBUG-BILD: {out_path}")


def main():
    print("Starte Download der gerenderten Wammsee-PNG-Tiles")
    print(f"Quelle: {BASE_URL}")
    print(f"Bounds: {BOUNDS}")
    print()

    total = 0
    ok = 0

    for z in range(MIN_ZOOM, MAX_ZOOM + 1):
        x_min, x_max, y_min, y_max = tile_range_for_bounds(BOUNDS, z)

        print()
        print(f"Zoom {z}: x={x_min}..{x_max}, y={y_min}..{y_max}")

        for x in range(x_min, x_max + 1):
            for y in range(y_min, y_max + 1):
                total += 1
                if download_tile(z, x, y):
                    ok += 1

        make_debug_mosaic(z, x_min, x_max, y_min, y_max)

    print()
    print("Fertig.")
    print(f"Tiles gesamt: {total}")
    print(f"Erfolgreich:  {ok}")
    print(f"Ausgabe:      {OUT_DIR}")
    print(f"Debugbilder:  {DEBUG_DIR}")


if __name__ == "__main__":
    main()
