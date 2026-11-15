#!/usr/bin/env python3
"""Generates the game's sprite sheets into assets/sprites/.

Run from the project folder:  python3 tools/make_art.py
Needs Pillow (pip install pillow).

Every sprite is built from simple shapes, then given automatic shading and a
dark outline. To use hand-drawn art instead, replace any PNG with one of the
same size and frame layout (see the comments on each section) and stop running
this script for that file.
"""
import math
import os
import random
from PIL import Image

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "sprites")
OUTLINE = (52, 36, 58, 255)
WHITE = (255, 255, 255)
DARK = (46, 32, 52)


def rgb(h):
    return tuple(int(h[i:i + 2], 16) for i in (1, 3, 5))


def mix(a, b, t):
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))


def light(c, t=0.22):
    return mix(c, (255, 250, 235), t)


def shade(c, t=0.22):
    return mix(c, (40, 24, 60), t)


class Canvas:
    """A small pixel canvas. Shapes go in `p`; `over` pixels (faces, sparkles)
    are stamped on afterwards so shading never touches them."""

    def __init__(self, w, h):
        self.w, self.h = w, h
        self.p = [[None] * w for _ in range(h)]
        self.over = []

    def px(self, x, y, c):
        x, y = int(x), int(y)
        if 0 <= x < self.w and 0 <= y < self.h:
            self.p[y][x] = c

    def rect(self, x, y, w, h, c):
        for j in range(int(h)):
            for i in range(int(w)):
                self.px(x + i, y + j, c)

    def ell(self, cx, cy, rx, ry, c, top_only=False, bottom_only=False):
        for y in range(self.h):
            for x in range(self.w):
                if top_only and y > cy:
                    continue
                if bottom_only and y < cy:
                    continue
                if ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1.0:
                    self.px(x, y, c)

    def tri(self, cx, top, half, height, c):
        """Upright triangle: tip at (cx, top), base `half` wide each side."""
        for j in range(int(height)):
            r = half * (j + 1) / height
            for x in range(self.w):
                if abs(x - cx) <= r:
                    self.px(x, top + j, c)

    def dot(self, x, y, c):
        self.over.append((int(x), int(y), c))

    def face(self, x, y, happy=True, gap=3):
        """Two eyes (2px tall) starting at x, and a little smile."""
        for ex in (x, x + gap):
            self.dot(ex, y, DARK)
            self.dot(ex, y + 1, DARK)
        if happy:
            for i in range(1, gap):
                self.dot(x + i, y + 3, DARK)

    def finish(self, outline=True, shading=True):
        w, h, p = self.w, self.h, self.p

        def empty(x, y):
            return not (0 <= x < w and 0 <= y < h) or p[y][x] is None

        img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        for y in range(h):
            for x in range(w):
                c = p[y][x]
                if c is None:
                    if outline and not all(empty(x + dx, y + dy) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                        img.putpixel((x, y), OUTLINE)
                    continue
                if shading:
                    def differs(dx, dy):
                        return empty(x + dx, y + dy) or p[y + dy][x + dx] != c
                    if differs(0, -1) or differs(-1, 0):
                        c = light(c, 0.2)
                    elif differs(0, 1) or differs(1, 0):
                        c = shade(c, 0.18)
                img.putpixel((x, y), c + (255,))
        for x, y, c in self.over:
            if 0 <= x < w and 0 <= y < h:
                img.putpixel((x, y), c + (255,) if len(c) == 3 else c)
        return img


def sheet(frames):
    w, h = frames[0].size
    out = Image.new("RGBA", (w * len(frames), h), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        out.paste(f, (i * w, 0))
    return out


def save(img, *path):
    full = os.path.join(OUT, *path)
    os.makedirs(os.path.dirname(full), exist_ok=True)
    img.save(full)


# ---------------------------------------------------------------- plants
# assets/sprites/plants/<id>.png, frames 16x24 left to right:
#   seed, one frame per growing stage, in bloom, radiant, resting
# ("resting" is the just-picked look of plants that regrow; others repeat the
# bloom frame so every sheet has stages + 3 frames... see FRAME notes below).
# The plant stands on y=22, centred on x=7.5.

PLANTS = {
    # id: (shape, growing stages, leaf, bloom, radiant, accent)
    "sunpuff": ("flower", 3, "#4da355", "#ffcf4a", "#fff3b8", "#f79a3c"),
    "moonbell": ("bush", 3, "#3f8a78", "#8f9bff", "#e3c8ff", "#5a6bd8"),
    "dewcup": ("tulip", 3, "#58a85a", "#ff8fb3", "#ffd9ea", "#e85d8f"),
    "pricklepal": ("cactus", 3, "#5fae6a", "#ff7fa8", "#ffe07a", "#3f8a52"),
    "gigglecap": ("mushroom", 4, "#8aa35a", "#e8584f", "#ff8fd6", "#f3e9d2"),
    "lanternsquash": ("gourd", 4, "#5c9a4c", "#f08a2e", "#ffd35c", "#c9641c"),
    "frostwhisker": ("flower", 3, "#6fa8b5", "#bfe9ff", "#ffffff", "#7fbfe6"),
    "snowpip": ("pine", 3, "#3f7f6a", "#ffffff", "#ffe9a8", "#2f6455"),
}
SOIL_SEED = rgb("#e9d7a3")
GROUND = 22


def sparkles(c, rng):
    for _ in range(4):
        c.dot(rng.choice([1, 2, 13, 14, 3, 12]), rng.randint(3, 16), WHITE)


def stem(c, top, leaf, leaves=True):
    c.rect(7, top, 2, GROUND - top + 1, leaf)
    if leaves and GROUND - top >= 5:
        c.rect(4, GROUND - 4, 3, 2, light(leaf, 0.1))
        c.rect(9, GROUND - 6, 3, 2, light(leaf, 0.1))


def plant_frame(shape, kind, g, leaf, bloom, accent, rng):
    """kind: seed | grow (g = 0..1 through the growing stages) | bloom | radiant | rest"""
    c = Canvas(16, 24)
    if kind == "seed":
        c.rect(5, GROUND - 1, 2, 2, SOIL_SEED)
        c.rect(9, GROUND, 2, 1, SOIL_SEED)
        c.rect(7, GROUND - 3, 2, 2, leaf)  # the first green tip
        return c.finish()
    if kind == "grow":
        height = int(4 + g * 8)
        top = GROUND - height
        if shape in ("bush", "gourd"):
            c.ell(7.5, GROUND - height / 2.5, 2.5 + g * 3.5, 1.5 + g * 3, leaf)
            c.rect(7, GROUND - 2, 2, 3, shade(leaf))
        elif shape == "cactus":
            c.rect(6, top + 2, 4, height - 1, leaf)
            c.rect(7, top + 1, 2, 1, leaf)
            if g > 0.5:
                c.rect(3, GROUND - 6, 3, 2, leaf)
                c.rect(3, GROUND - 8, 2, 2, leaf)
        elif shape == "mushroom":
            c.rect(7, GROUND - 2 - int(g * 3), 2, 3 + int(g * 3), accent)
            c.ell(7.5, GROUND - 3 - int(g * 3), 2 + g * 3, 1.5 + g * 2, shade(bloom, 0.1), top_only=True)
        elif shape == "pine":
            c.rect(7, GROUND - 1, 2, 2, rgb("#7a5a3a"))
            c.tri(7.5, top, 2 + g * 3, height - 1, leaf)
        else:  # flower, tulip
            stem(c, top, leaf)
            if g > 0.6:
                c.ell(7.5, top, 2.2, 2.2, shade(bloom, 0.25))  # bud
        return c.finish()

    resting = kind == "rest"
    if shape == "flower":
        stem(c, 10, leaf)
        c.ell(7.5, 7.5, 5.6, 5.6, accent if not resting else shade(leaf, 0.1))
        for a in range(0, 360, 45):  # petals
            c.ell(7.5 + 4.2 * math.cos(math.radians(a)), 7.5 + 4.2 * math.sin(math.radians(a)), 1.8, 1.8, bloom)
        c.ell(7.5, 7.5, 3.3, 3.3, light(bloom, 0.45))
        c.face(6, 6)
    elif shape == "tulip":
        stem(c, 9, leaf)
        c.rect(4, 5, 8, 6, bloom)
        c.ell(7.5, 10, 4.2, 3, bloom, bottom_only=True)
        for x in (4, 7, 10):
            c.rect(x, 3, 2, 2, bloom)
        c.rect(5, 4, 1, 1, bloom)
        c.rect(10, 4, 1, 1, bloom)
        c.rect(7, 6, 2, 5, light(bloom, 0.3))
        c.face(6, 7)
    elif shape == "bush":
        c.rect(7, GROUND - 1, 2, 2, rgb("#7a5a3a"))
        c.ell(7.5, 15, 6.6, 5.6, leaf)
        c.ell(5, 11.5, 3, 2.6, leaf)
        c.ell(10.5, 11.5, 3, 2.6, leaf)
        if not resting:
            for bx, by in ((3, 16), (11, 12), (7, 10), (12, 17), (4, 12)):
                c.rect(bx, by, 2, 2, bloom)
                c.dot(bx, by, light(bloom, 0.5))
        c.face(6, 15)
    elif shape == "mushroom":
        c.rect(5, 15, 6, 8, accent)
        c.ell(7.5, 14, 7, 6.5, bloom, top_only=True)
        c.rect(1, 13, 14, 2, bloom)
        for sx, sy in ((3, 11), (10, 9), (6, 9), (12, 12)):
            c.rect(sx, sy, 2, 2, light(bloom, 0.75))
        c.face(6, 17)
    elif shape == "cactus":
        c.rect(5, 9, 6, 14, leaf)
        c.rect(6, 8, 4, 1, leaf)
        c.rect(1, 12, 3, 2, leaf)
        c.rect(1, 10, 2, 3, leaf)
        c.rect(3, 13, 2, 2, leaf)
        c.rect(12, 14, 3, 2, leaf)
        c.rect(13, 11, 2, 4, leaf)
        c.rect(11, 15, 2, 2, leaf)
        for sy in (11, 15, 19):
            c.dot(5, sy, light(leaf, 0.5))
            c.dot(10, sy + 1, light(leaf, 0.5))
        if not resting:
            c.ell(7.5, 6, 2.6, 2.2, bloom)
            c.dot(7, 6, light(bloom, 0.6))
            c.dot(8, 6, light(bloom, 0.6))
        c.face(6, 14)
    elif shape == "gourd":
        c.rect(7, 8, 2, 3, leaf)
        c.rect(9, 8, 3, 2, light(leaf, 0.1))
        c.ell(7.5, 16.5, 6.6, 5.6, bloom)
        for x in (4, 11):
            c.rect(x, 13, 1, 8, accent)
        c.face(6, 15)
        c.dot(5, 17, light(bloom, 0.6))
        c.dot(10, 17, light(bloom, 0.6))
    elif shape == "pine":
        c.rect(7, GROUND - 2, 2, 3, rgb("#7a5a3a"))
        c.tri(7.5, 2, 3.4, 6, leaf)
        c.tri(7.5, 6, 5, 7, leaf)
        c.tri(7.5, 11, 6.5, 9, leaf)
        if not resting:
            for bx, by in ((5, 9), (10, 12), (4, 17), (11, 18), (8, 5)):
                c.rect(bx, by, 2, 2, bloom)
        c.face(6, 14)
    if kind == "radiant":
        sparkles(c, rng)
    return c.finish()


def make_plants():
    for pid, (shape, stages, leaf, bloom, radiant, accent) in PLANTS.items():
        rng = random.Random(pid)
        leaf, bloom, radiant, accent = rgb(leaf), rgb(bloom), rgb(radiant), rgb(accent)
        frames = [plant_frame(shape, "seed", 0, leaf, bloom, accent, rng)]
        for i in range(1, stages):
            frames.append(plant_frame(shape, "grow", i / (stages - 1) if stages > 1 else 1, leaf, bloom, accent, rng))
        frames.append(plant_frame(shape, "bloom", 1, leaf, bloom, accent, rng))
        frames.append(plant_frame(shape, "radiant", 1, light(leaf, 0.12), radiant, light(accent, 0.3), rng))
        frames.append(plant_frame(shape, "rest", 1, leaf, bloom, accent, rng))
        save(sheet(frames), "plants", pid + ".png")


# ---------------------------------------------------------------- players
# assets/sprites/player_<slot>.png: 16x24 frames, 2 columns (standing, step),
# 4 rows (facing down, up, left, right). Feet on y=22.

def player_frame(direction, step, overalls):
    c = Canvas(16, 24)
    skin, hair, hat, band = rgb("#ffd9b8"), rgb("#8a5a3c"), rgb("#f2d774"), rgb("#e0605a")
    boots, shirt = rgb("#6b4a36"), rgb("#fff4dc")
    lift = 1 if step else 0
    side = direction in ("left", "right")
    if side:
        c.rect(5, 20 - lift, 3, 3 + lift - (1 if step else 0), boots)
        c.rect(8, 20, 3, 3, boots)
        c.rect(5, 13, 6, 7, overalls)
        c.rect(6, 12, 4, 2, shirt)
        c.rect(7, 14, 2, 4, shirt)  # arm
        c.rect(7, 18, 2, 1, skin)
    else:
        c.rect(4, 20 - lift, 3, 3, boots)
        c.rect(9, 20 - (0 if step else 0) + (0 if not step else 0), 3, 3, boots)
        c.rect(4, 13, 8, 7, overalls)
        c.rect(3, 13, 1, 5, shirt)
        c.rect(12, 13, 1, 5, shirt)
        c.rect(3, 18, 1, 1, skin)
        c.rect(12, 18, 1, 1, skin)
        if direction == "down":
            c.rect(6, 12, 4, 2, shirt)
            c.dot(5, 14, light(overalls, 0.5))  # buttons
            c.dot(10, 14, light(overalls, 0.5))
    c.rect(4, 6, 8, 7, skin)  # head
    if direction == "up":
        c.rect(4, 6, 8, 6, hair)
    elif side:
        back = 4 if direction == "right" else 9
        c.rect(back, 6, 3, 6, hair)
    else:
        c.rect(4, 6, 8, 1, hair)
        c.rect(4, 7, 1, 3, hair)
        c.rect(11, 7, 1, 3, hair)
    c.rect(2, 5, 12, 2, hat)  # brim
    c.rect(4, 2, 8, 3, hat)  # crown
    c.rect(4, 4, 8, 1, band)
    if direction == "down":
        c.face(5, 8, happy=False, gap=5)
        c.dot(4, 11, rgb("#ffb3a8"))
        c.dot(11, 11, rgb("#ffb3a8"))
        c.dot(7, 11, DARK)
        c.dot(8, 11, DARK)
    elif side:
        ex = 10 if direction == "right" else 5
        c.dot(ex, 8, DARK)
        c.dot(ex, 9, DARK)
    return c.finish()


def make_players():
    for slot, colour in ((1, "#4f7fd1"), (2, "#e0739f")):
        out = Image.new("RGBA", (32, 96), (0, 0, 0, 0))
        for row, direction in enumerate(("down", "up", "left", "right")):
            for col in (0, 1):
                out.paste(player_frame(direction, col == 1, rgb(colour)), (col * 16, row * 24))
        save(out, "player_%d.png" % slot)


# ------------------------------------------------------------------ tiles
# assets/tiles/ground.png: 16x16 tiles, one row per season (spring, summer,
# fall, winter). Columns: grass, grass, grass with tufts, grass with a seasonal
# decoration, dry soil, wet soil. Soil has see-through corners and sits on grass.

SEASON_GRASS = ["#79c267", "#5fb155", "#c9a24f", "#e3ecf2"]
SEASON_DECO = ["#ff9fc2", "#fff3a0", "#d9682f", "#ffffff"]


def grass_tile(base, rng, tufts=0, deco=None):
    c = Canvas(16, 16)
    c.rect(0, 0, 16, 16, base)
    img = c.finish(outline=False, shading=False)
    for _ in range(10):
        x, y = rng.randrange(16), rng.randrange(16)
        img.putpixel((x, y), (shade(base, 0.07) if rng.random() < 0.5 else light(base, 0.1)) + (255,))
    for _ in range(tufts):
        x, y = rng.randrange(2, 13), rng.randrange(3, 14)
        for dx, dy in ((0, 0), (0, -1), (1, 0), (2, -1), (2, 0)):
            img.putpixel((x + dx, y + dy), shade(base, 0.2) + (255,))
    if deco:
        x, y = rng.randrange(3, 11), rng.randrange(3, 11)
        for dx, dy in ((1, 0), (0, 1), (2, 1), (1, 2)):
            img.putpixel((x + dx, y + dy), deco + (255,))
        img.putpixel((x + 1, y + 1), light(deco, 0.6) + (255,))
    return img


def soil_tile(colour, rim):
    c = Canvas(16, 16)
    c.rect(1, 2, 14, 12, rim)
    c.rect(2, 1, 12, 14, rim)
    c.rect(2, 2, 12, 12, colour)
    for y in (4, 8, 12):
        c.rect(3, y, 10, 1, shade(colour, 0.2))
        c.rect(3, y - 1, 10, 1, light(colour, 0.08))
    return c.finish(outline=False, shading=False)


def make_tiles():
    out = Image.new("RGBA", (96, 64), (0, 0, 0, 0))
    for row in range(4):
        rng = random.Random(row)
        base, deco = rgb(SEASON_GRASS[row]), rgb(SEASON_DECO[row])
        tiles = [
            grass_tile(base, rng), grass_tile(shade(base, 0.04), rng),
            grass_tile(base, rng, tufts=2), grass_tile(base, rng, tufts=1, deco=deco),
            soil_tile(rgb("#a8774a"), rgb("#8a5e3a")), soil_tile(rgb("#6b4630"), rgb("#553726")),
        ]
        for col, tile in enumerate(tiles):
            out.paste(tile, (col * 16, row * 16))
    full = os.path.join(OUT, "..", "tiles", "ground.png")
    os.makedirs(os.path.dirname(full), exist_ok=True)
    out.save(full)


# ------------------------------------------------------- tent & Heart Tree
# assets/sprites/tent.png: one 48x48 picture, base on the bottom row.
# assets/sprites/heart_tree.png: five 48x64 frames (seed, sprout, sapling,
# young tree, in bloom), base on the bottom row.

def make_tent():
    c = Canvas(48, 48)
    cloth, stripe, door = rgb("#f08a78"), rgb("#ffd9b0"), rgb("#5a3a52")
    c.tri(23.5, 8, 22, 38, cloth)
    for j in range(38):
        r = 22 * (j + 1) / 38
        for x in range(48):
            d = abs(x - 23.5)
            if d <= r and (0.42 * r < d < 0.62 * r):
                c.px(x, 8 + j, stripe)
    c.tri(23.5, 22, 7, 24, door)
    c.rect(23, 2, 2, 7, rgb("#7a5a3a"))
    c.rect(25, 2, 6, 4, rgb("#ffd35c"))
    save(c.finish(), "tent.png")


def tree_frame(stage):
    c = Canvas(48, 64)
    bark, leaf, pink = rgb("#8a6044"), rgb("#57a868"), rgb("#ff8fb3")
    # A ring of stones marks its spot.
    c.ell(23.5, 58, 17, 4.5, rgb("#8f6a48"))
    for i in range(9):
        a = math.pi * i / 8
        c.ell(23.5 - 17 * math.cos(a), 58.5 + 3.5 * math.sin(a), 2.4, 1.8, rgb("#b9b3c4"))
    heart = [(0, 1), (1, 0), (2, 1), (3, 0), (4, 1), (0, 2), (1, 2), (2, 2), (3, 2), (4, 2), (1, 1), (3, 1), (1, 3), (2, 3), (3, 3), (2, 4)]
    if stage == 0:
        for dx, dy in heart:
            c.rect(19 + dx * 2, 46 + dy * 2, 2, 2, pink)
        c.dot(21, 49, WHITE)
        c.face(21, 50, gap=4)
    elif stage == 1:
        c.rect(23, 44, 2, 13, leaf)
        c.ell(19, 44, 4.5, 3, leaf)
        c.ell(28, 41, 4.5, 3, leaf)
        c.ell(23.5, 37, 3, 3, pink)
    else:
        trunk_h = (16, 24, 28)[stage - 2]
        trunk_w = (4, 6, 8)[stage - 2]
        top = 57 - trunk_h
        c.rect(24 - trunk_w // 2, top, trunk_w, trunk_h + 1, bark)
        c.rect(24 - trunk_w // 2 - 2, 55, trunk_w + 4, 3, bark)
        radius = (9, 15, 19)[stage - 2]
        cy = top - radius * 0.45
        c.ell(23.5, cy, radius, radius * 0.8, leaf)
        c.ell(23.5 - radius * 0.6, cy + radius * 0.3, radius * 0.6, radius * 0.5, leaf)
        c.ell(23.5 + radius * 0.6, cy + radius * 0.3, radius * 0.6, radius * 0.5, leaf)
        rng = random.Random(stage)
        blossoms = (0, 5, 14)[stage - 2]
        for _ in range(blossoms):
            a, d = rng.uniform(0, math.tau), rng.uniform(0.1, 0.8)
            bx, by = int(23.5 + math.cos(a) * radius * d), int(cy + math.sin(a) * radius * 0.65 * d)
            for dx, dy in ((0, 0), (2, 0), (0, 1), (1, 1), (2, 1), (1, 2)):
                c.dot(bx + dx - 1, by + dy, pink)
            c.dot(bx - 1, by, light(pink, 0.5))
        fy = top + trunk_h // 2 - 1
        c.face(22 if trunk_w > 4 else 22, fy, gap=3 if trunk_w > 4 else 3)
    return c.finish()


def make_tree():
    save(sheet([tree_frame(s) for s in range(5)]), "heart_tree.png")


if __name__ == "__main__":
    make_plants()
    make_players()
    make_tiles()
    make_tent()
    make_tree()
    print("sprites written to", os.path.normpath(OUT))
