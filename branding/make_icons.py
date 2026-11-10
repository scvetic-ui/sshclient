"""Draws the app icon (a halved orange) and writes all Android icon sizes.
Run: python3 branding/make_icons.py   (needs Pillow)"""
import math, os
from PIL import Image, ImageDraw

S = 2048  # supersampled canvas

def orange(size_frac, with_bg):
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    if with_bg:
        d.rounded_rectangle([0, 0, S - 1, S - 1], radius=int(S * 0.22), fill=(0, 131, 143, 255))
    c = S / 2
    R = S * size_frac / 2
    def circle(r, fill):
        d.ellipse([c - r, c - r, c + r, c + r], fill=fill)
    circle(R, (239, 108, 0, 255))            # rind
    circle(R * 0.93, (255, 236, 205, 255))   # pith
    flesh = R * 0.86
    n = 10
    for i in range(n):                        # juicy wedges
        a0 = i * 360 / n - 90 + 2.2
        a1 = (i + 1) * 360 / n - 90 - 2.2
        col = (255, 167, 38, 255) if i % 2 == 0 else (255, 183, 77, 255)
        d.pieslice([c - flesh, c - flesh, c + flesh, c + flesh], a0, a1, fill=col)
    circle(R * 0.085, (255, 236, 205, 255))   # centre
    # little highlights on wedges
    for i in range(n):
        a = math.radians((i + 0.5) * 360 / n - 90)
        for k, rr in enumerate((0.45, 0.68)):
            x = c + math.cos(a) * flesh * rr
            y = c + math.sin(a) * flesh * rr
            h = R * (0.035 - 0.01 * k)
            d.ellipse([x - h, y - h, x + h, y + h], fill=(255, 224, 160, 255))
    return img

def save(img, size, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.resize((size, size), Image.LANCZOS).save(path)

here = os.path.dirname(os.path.abspath(__file__))
res = os.path.join(here, "res")
legacy = orange(0.66, True)         # full icon for old launchers + Play Store
fore = orange(0.58, False)          # adaptive foreground (inside the safe zone)
for name, px, fpx in [("mdpi", 48, 108), ("hdpi", 72, 162), ("xhdpi", 96, 216),
                      ("xxhdpi", 144, 324), ("xxxhdpi", 192, 432)]:
    save(legacy, px, f"{res}/mipmap-{name}/ic_launcher.png")
    save(fore, fpx, f"{res}/mipmap-{name}/ic_launcher_foreground.png")
os.makedirs(f"{res}/mipmap-anydpi-v26", exist_ok=True)
open(f"{res}/mipmap-anydpi-v26/ic_launcher.xml", "w").write(
    '<?xml version="1.0" encoding="utf-8"?>\n'
    '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
    '    <background android:drawable="@color/ic_launcher_background"/>\n'
    '    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>\n'
    '</adaptive-icon>\n')
os.makedirs(f"{res}/values", exist_ok=True)
open(f"{res}/values/ic_launcher_background.xml", "w").write(
    '<?xml version="1.0" encoding="utf-8"?>\n<resources>\n'
    '    <color name="ic_launcher_background">#00838F</color>\n</resources>\n')
save(legacy, 512, os.path.join(here, "play-store-icon-512.png"))
print("done")
