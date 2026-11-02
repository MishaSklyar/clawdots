"""Render Clawd pixel art: clawd.png (1920x1080 wallpaper) and clawd-lock.png (square, for hyprlock)."""
from pathlib import Path
from PIL import Image, ImageDraw

HERE = Path(__file__).parent
ORANGE, BLACK = (218, 119, 86), (0, 0, 0)

cells = set()
def fill(r, c0, c1):
    for c in range(c0, c1 + 1): cells.add((r, c))
fill(0, 2, 9); fill(1, 2, 9)
fill(2, 0, 11); fill(3, 0, 11)
fill(4, 2, 9); fill(5, 2, 9)
for c in (2, 4, 7, 9): fill(6, c, c); fill(7, c, c)
eyes = {(1, 3), (1, 8)}


def draw(img, ox, oy, u):
    d = ImageDraw.Draw(img)
    for r, c in cells:
        col = BLACK if (r, c) in eyes else ORANGE
        d.rectangle([ox + c * u, oy + r * u, ox + (c + 1) * u - 1, oy + (r + 1) * u - 1], fill=col)


# wallpaper: dot-matrix grid that warms up toward Clawd, pixel shadow
W, H, U = 1920, 1080, 28
bg = Image.new("RGB", (W, H), BLACK)
d = ImageDraw.Draw(bg)
ox, oy = (W - 12 * U) // 2, (H - 8 * U) // 2
cx, cy = W / 2, H / 2
G = U // 2                                # dot grid pitch: half a sprite pixel
for y in range(G // 2, H, G):
    for x in range(G // 2, W, G):
        dist = ((x - cx) ** 2 + ((y - cy) * 1.6) ** 2) ** 0.5
        heat = max(0.0, 1 - dist / 900) ** 2.2    # 1 at Clawd, 0 far away
        base = 40                                  # far dots: dark grey
        col = tuple(int(base + (o * 0.7 - base) * heat) for o in ORANGE)
        d.rectangle([x - 1, y - 1, x + 1, y + 1], fill=col)
# offset pixel shadow, then the sprite
for r, c in cells:
    x0, y0 = ox + c * U + U // 2, oy + r * U + U // 2
    d.rectangle([x0, y0, x0 + U - 1, y0 + U - 1], fill=(58, 30, 22))
draw(bg, ox, oy, U)
bg.save(HERE / "clawd.png")


def draw2(img, ox, oy, u, body, eye):
    d = ImageDraw.Draw(img)
    for r, c in cells:
        d.rectangle([ox + c * u, oy + r * u, ox + (c + 1) * u - 1, oy + (r + 1) * u - 1], fill=eye if (r, c) in eyes else body)


# plain: black, big Clawd, nothing else
im = Image.new("RGB", (W, H), BLACK)
draw(im, ox, oy, U)
im.save(HERE / "clawd-plain.png")

# inverted: orange screen, black Clawd with orange eyes
im = Image.new("RGB", (W, H), ORANGE)
draw2(im, ox, oy, U, BLACK, ORANGE)
im.save(HERE / "clawd-inverted.png")

# corner: tiny Clawd sitting bottom-right, lots of black
im = Image.new("RGB", (W, H), BLACK)
u = 8
draw(im, W - 12 * u - 64, H - 8 * u - 48, u)
im.save(HERE / "clawd-corner.png")

# army: a dim grid of Clawds, one of them orange
im = Image.new("RGB", (W, H), BLACK)
u, gx, gy = 6, 120, 96
cols, rows = W // gx, H // gy
mx, my = (W - cols * gx) // 2, (H - rows * gy) // 2
for j in range(rows):
    for i in range(cols):
        x = mx + i * gx + (gx - 12 * u) // 2
        y = my + j * gy + (gy - 8 * u) // 2
        hero = (i, j) == (cols * 2 // 3, rows // 3)
        draw2(im, x, y, u, ORANGE if hero else (28, 28, 30), BLACK)
im.save(HERE / "clawd-army.png")

# lock-screen sprite: square canvas (hyprlock crops images to a square), sprite centered
S, U = 120, 10
lock = Image.new("RGB", (S, S), BLACK)
draw(lock, (S - 12 * U) // 2, (S - 8 * U) // 2, U)
lock.save(HERE / "clawd-lock.png")
