"""Draws the 1024x500 Google Play feature graphic. Run: python3 branding/make_feature_graphic.py"""
import os, runpy
from PIL import Image, ImageDraw, ImageFont
here = os.path.dirname(os.path.abspath(__file__))
# reuse lemon drawing without writing icons
src = open(os.path.join(here, "make_icons.py")).read().split("def save(")[0]
ns = {}; exec(src, ns)
lemon = ns["lemon"](0.9, False).resize((400, 400))
W, H = 1024, 500
img = Image.new("RGB", (W, H), (0, 131, 143))
d = ImageDraw.Draw(img)
for y in range(H):  # subtle vertical gradient
    t = y / H
    d.line([(0, y), (W, y)], fill=(int(0 + 0 * t), int(131 - 40 * t), int(143 - 40 * t)))
B = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
M = "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf"
# terminal prompt strip
d.rounded_rectangle([40, 340, 560, 440], radius=14, fill=(16, 42, 52))
d.text((62, 372), "$ ssh admin@server", font=ImageFont.truetype(M, 30), fill=(253, 216, 53))
d.text((62, 40), "LemonSSH", font=ImageFont.truetype(B, 92), fill=(255, 255, 255))
d.text((66, 165), "SSH, Telnet & local shell", font=ImageFont.truetype(B, 38), fill=(255, 245, 190))
d.text((66, 222), "Keys · Snippets · Port forwarding", font=ImageFont.truetype(B, 27), fill=(210, 240, 243))
d.text((66, 270), "Sessions stay connected", font=ImageFont.truetype(B, 30), fill=(210, 240, 243))
img.paste(lemon, (610, 50), lemon)
img.save(os.path.join(here, "feature-graphic-1024x500.png"))
