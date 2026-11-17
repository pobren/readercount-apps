# Puts a Mac window screenshot on a 1280 by 800 background (the App Store's smallest Mac size), scaling down only
# if the window is too big. Usage: mac-frame.py in.png out.png
import sys
from PIL import Image

src = Image.open(sys.argv[1]).convert("RGBA")
W, H = 1280, 800
bg = Image.new("RGBA", (W, H))
top, bottom = (238, 242, 248), (214, 224, 238)
for y in range(H):
    t = y / (H - 1)
    c = tuple(round(top[i] + (bottom[i] - top[i]) * t) for i in range(3)) + (255,)
    bg.paste(c, (0, y, W, y + 1))
scale = min(1.0, (W - 60) / src.width, (H - 40) / src.height)
if scale < 1:
    src = src.resize((round(src.width * scale), round(src.height * scale)), Image.LANCZOS)
bg.alpha_composite(src, ((W - src.width) // 2, (H - src.height) // 2))
bg.convert("RGB").save(sys.argv[2])
