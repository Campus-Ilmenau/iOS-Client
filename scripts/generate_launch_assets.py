#!/usr/bin/env python3
"""Erzeugt die statischen Launch-Screen-Bilder (erster Frame der Start-Animation).

Light: weiße Ziege. Dark: nachtblaue Ziege vor Abendsonne mit Horizont an den Hufen.
Maße und Geometrie wie Design/Logo 2026/Launch/index.html (Ziege 180 pt breit,
10 pt über der Bildschirmmitte). Die Wand selbst ist die Vollfarbe `launchWall`.

Aufruf: python3 scripts/generate_launch_assets.py
"""
import json
import math
import re
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
SVG = ROOT / "Design/Logo 2026/Launch/Goat Mask.svg"
OUT = ROOT / "Campus Ilmenau/Assets.xcassets/LaunchGoat.imageset"

GOAT_W = 180.0
K = GOAT_W / 996.0                      # pt pro Pfad-Einheit
CANVAS_W, CANVAS_H = 224, 256           # pt
GOAT_CENTER = (498.0, 500.0)            # Pfad-Einheiten
CANVAS_GOAT_CENTER = (CANVAS_W / 2, CANVAS_H / 2 - 10)   # Ziege 10 pt über der Mitte
SUN = {"cx": 527.0, "cy": 443.0, "r": 587.0, "horizon": 996.0}
SUN_COLORS = ((0xFF, 0x5C, 0x1A), (0xFF, 0xB1, 0x21))
GOAT_COLORS = {"light": (0xFF, 0xFF, 0xFF), "dark": (0x0E, 0x1A, 0x2E)}
SS = 4                                  # Supersampling


def parse_path(svg_text):
    d = re.search(r' d="([^"]+)"', svg_text).group(1)
    tokens = re.findall(r"[MLCZ]|-?\d+\.?\d*", d)
    pts, i, cur = [], 0, (0.0, 0.0)
    cmd = None
    while i < len(tokens):
        if tokens[i] in "MLCZ":
            cmd = tokens[i]
            i += 1
            if cmd == "Z":
                continue
        if cmd in "ML":
            cur = (float(tokens[i]), float(tokens[i + 1]))
            pts.append(cur)
            i += 2
        elif cmd == "C":
            c1 = (float(tokens[i]), float(tokens[i + 1]))
            c2 = (float(tokens[i + 2]), float(tokens[i + 3]))
            end = (float(tokens[i + 4]), float(tokens[i + 5]))
            for n in range(1, 25):
                t = n / 24
                u = 1 - t
                pts.append((
                    u**3 * cur[0] + 3 * u * u * t * c1[0] + 3 * u * t * t * c2[0] + t**3 * end[0],
                    u**3 * cur[1] + 3 * u * u * t * c1[1] + 3 * u * t * t * c2[1] + t**3 * end[1],
                ))
            cur = end
            i += 6
    return pts


def to_px(point, scale):
    x = CANVAS_GOAT_CENTER[0] + (point[0] - GOAT_CENTER[0]) * K
    y = CANVAS_GOAT_CENTER[1] + (point[1] - GOAT_CENTER[1]) * K
    return (x * scale * SS, y * scale * SS)


def render(mode, scale, goat_pts):
    w, h = CANVAS_W * scale * SS, CANVAS_H * scale * SS
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))

    if mode == "dark":
        top = to_px((SUN["cx"], SUN["cy"] - SUN["r"]), scale)[1]
        bottom = to_px((SUN["cx"], SUN["cy"] + SUN["r"]), scale)[1]
        grad = Image.new("RGBA", (w, h))
        gd = ImageDraw.Draw(grad)
        for y in range(h):
            f = min(1, max(0, (y - top) / (bottom - top)))
            col = tuple(round(a + (b - a) * f) for a, b in zip(*SUN_COLORS))
            gd.line([(0, y), (w, y)], fill=col + (255,))
        mask = Image.new("L", (w, h), 0)
        cx, cy = to_px((SUN["cx"], SUN["cy"]), scale)
        r = SUN["r"] * K * scale * SS
        ImageDraw.Draw(mask).ellipse([cx - r, cy - r, cx + r, cy + r], fill=255)
        # Horizont an den Hufen: darunter keine Sonne
        horizon_y = to_px((0, SUN["horizon"]), scale)[1]
        ImageDraw.Draw(mask).rectangle([0, horizon_y, w, h], fill=0)
        img.paste(grad, (0, 0), mask)

    goat = Image.new("L", (w, h), 0)
    ImageDraw.Draw(goat).polygon([to_px(p, scale) for p in goat_pts], fill=255)
    color = Image.new("RGBA", (w, h), GOAT_COLORS[mode] + (255,))
    img.paste(color, (0, 0), goat)
    return img.resize((CANVAS_W * scale, CANVAS_H * scale), Image.LANCZOS)


def main():
    goat_pts = parse_path(SVG.read_text())
    OUT.mkdir(parents=True, exist_ok=True)
    for old in OUT.glob("*.png"):
        old.unlink()
    images = []
    for mode in ("light", "dark"):
        for scale in (1, 2, 3):
            name = f"launch-goat-{mode}@{scale}x.png"
            render(mode, scale, goat_pts).save(OUT / name)
            entry = {"filename": name, "idiom": "universal", "scale": f"{scale}x"}
            if mode == "dark":
                entry = {"appearances": [{"appearance": "luminosity", "value": "dark"}], **entry}
            images.append(entry)
    (OUT / "Contents.json").write_text(
        json.dumps({"images": images, "info": {"author": "xcode", "version": 1}}, indent=2) + "\n"
    )
    print("ok", len(images), "images")


if __name__ == "__main__":
    main()
