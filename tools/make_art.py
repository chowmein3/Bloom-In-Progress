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
# assets/sprites/player_<slot>.png: 16x24 frames, 3 columns (standing, left
# foot forward, right foot forward; the game plays 1-0-2-0 as the walk),
# 5 rows (facing down, up, left, right, asleep). Feet on y=22. Players are
# drawn bare-headed; the hat they wear is laid on top from hats.png.

def player_frame(direction, step, overalls):
    c = Canvas(16, 24)
    skin, hair = rgb("#ffd9b8"), rgb("#8a5a3c")
    boots, shirt = rgb("#6b4a36"), rgb("#fff4dc")
    # step: 0 standing, 1 left foot forward, 2 right foot forward. The arms
    # swing opposite the legs.
    side = direction in ("left", "right")
    if side:
        forward = 1 if direction == "right" else -1
        if step == 0:
            c.rect(5, 20, 3, 3, boots)
            c.rect(8, 20, 3, 3, boots)
        else:
            # Legs apart: one foot planted ahead, the other lifting behind.
            ahead, behind = (9, 4) if forward == 1 else (4, 9)
            c.rect(ahead, 20, 3, 3, boots)
            c.rect(behind, 19, 3, 3, boots)
            c.rect(6, 19, 4, 1, overalls)
        c.rect(5, 13, 6, 7, overalls)
        c.rect(6, 12, 4, 2, shirt)
        swing = 0 if step == 0 else (forward if step == 1 else -forward)
        c.rect(7 + swing, 14, 2, 4, shirt)  # arm
        c.rect(7 + swing * 2, 18, 2, 1, skin)
    else:
        c.rect(4, 20 - (1 if step == 1 else 0), 3, 3, boots)
        c.rect(9, 20 - (1 if step == 2 else 0), 3, 3, boots)
        c.rect(4, 13, 8, 7, overalls)
        left_arm = 1 if step == 2 else 0  # the arm opposite the lifted foot swings up
        right_arm = 1 if step == 1 else 0
        c.rect(3, 13 - left_arm, 1, 5, shirt)
        c.rect(12, 13 - right_arm, 1, 5, shirt)
        c.rect(3, 18 - left_arm, 1, 1, skin)
        c.rect(12, 18 - right_arm, 1, 1, skin)
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
    c.rect(4, 5, 8, 1, hair)  # top of the head
    c.rect(5, 4, 6, 1, hair)
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


def sleeping_head():
    """Just the head, eyes closed, for a player tucked up in bed."""
    c = Canvas(16, 24)
    skin, hair = rgb("#ffd9b8"), rgb("#8a5a3c")
    c.rect(4, 6, 8, 7, skin)
    c.rect(4, 5, 8, 2, hair)
    c.rect(5, 4, 6, 1, hair)
    c.rect(4, 7, 1, 3, hair)
    c.rect(11, 7, 1, 3, hair)
    for x in (5, 6, 9, 10):
        c.dot(x, 9, DARK)
    c.dot(4, 11, rgb("#ffb3a8"))
    c.dot(11, 11, rgb("#ffb3a8"))
    return c.finish()


def make_players():
    for slot, colour in ((1, "#4f7fd1"), (2, "#e0739f")):
        out = Image.new("RGBA", (48, 120), (0, 0, 0, 0))
        for row, direction in enumerate(("down", "up", "left", "right")):
            for col in (0, 1, 2):
                out.paste(player_frame(direction, col, rgb(colour)), (col * 16, row * 24))
        out.paste(sleeping_head(), (0, 96))
        save(out, "player_%d.png" % slot)


# ------------------------------------------------------------------- hats
# assets/sprites/hats.png: 16x12 frames, one per hat, in the order of
# GameState.HAT_ORDER (straw, flower, sprout, beanie, sun). A hat is drawn
# over the top 12 rows of a player frame.

def make_hats():
    def straw(c):
        c.rect(2, 5, 12, 2, rgb("#f2d774"))
        c.rect(4, 2, 8, 3, rgb("#f2d774"))
        c.rect(4, 4, 8, 1, rgb("#e0605a"))

    def flower(c):
        c.rect(3, 4, 10, 2, rgb("#5aa85a"))
        for x, colour in ((3, "#ff8fb3"), (6, "#ffd24a"), (9, "#ffffff"), (12, "#ff8fb3")):
            c.rect(x, 3, 2, 2, rgb(colour))

    def sprout(c):
        c.rect(7, 2, 2, 3, rgb("#5aa85a"))
        c.ell(4.5, 1.5, 2.4, 1.4, rgb("#6fc46a"))
        c.ell(10.5, 1.5, 2.4, 1.4, rgb("#6fc46a"))

    def beanie(c):
        c.rect(4, 2, 8, 4, rgb("#3fa7a0"))
        c.rect(5, 1, 6, 1, rgb("#3fa7a0"))
        c.rect(3, 5, 10, 2, rgb("#8fd9d2"))
        c.rect(7, 0, 2, 1, WHITE)

    def sun(c):
        c.rect(0, 5, 16, 2, rgb("#fff0c9"))
        c.rect(4, 2, 8, 3, rgb("#fff0c9"))
        c.rect(5, 1, 6, 1, rgb("#fff0c9"))
        c.rect(4, 4, 8, 1, rgb("#ff8fb3"))

    frames = []
    for draw in (straw, flower, sprout, beanie, sun):
        c = Canvas(16, 12)
        draw(c)
        frames.append(c.finish())
    save(sheet(frames), "hats.png")


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
# assets/sprites/home_<level>.png: the home from outside (tent, cabin,
# cottage), one 48x48 picture each, base on the bottom row.
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
    save(c.finish(), "home_0.png")


def make_cabin():
    c = Canvas(48, 48)
    log, roof = rgb("#a8744a"), rgb("#b5523f")
    c.rect(7, 24, 34, 22, log)
    for y in range(27, 46, 5):
        c.rect(7, y, 34, 1, shade(log, 0.25))
    c.tri(23.5, 6, 24, 19, roof)
    for y in range(11, 25, 4):
        c.rect(0, y, 48, 1, shade(roof, 0.2))
    for j in range(19):  # keep the roof stripes inside the roof
        r = 24 * (j + 1) / 19
        for x in range(48):
            if abs(x - 23.5) > r:
                c.p[6 + j][x] = None
    c.rect(20, 32, 8, 14, rgb("#6b4630"))
    c.dot(26, 39, rgb("#ffd24a"))
    c.rect(31, 30, 6, 6, rgb("#bfe6ff"))
    c.rect(33, 30, 1, 6, shade(log, 0.3))
    c.rect(11, 30, 6, 6, rgb("#bfe6ff"))
    c.rect(13, 30, 1, 6, shade(log, 0.3))
    save(c.finish(), "home_1.png")


def make_cottage():
    c = Canvas(48, 48)
    wall, beam, roof = rgb("#fbeed3"), rgb("#8a5e3a"), rgb("#3f8f86")
    c.rect(35, 2, 5, 12, rgb("#b9897a"))  # chimney
    c.rect(34, 1, 7, 2, rgb("#8f6558"))
    c.rect(5, 24, 38, 22, wall)
    c.rect(5, 24, 2, 22, beam)
    c.rect(41, 24, 2, 22, beam)
    c.rect(5, 44, 38, 2, beam)
    c.tri(23.5, 4, 25, 21, roof)
    for j in range(3, 21, 4):
        r = 25 * (j + 1) / 21
        for x in range(48):
            if abs(x - 23.5) <= r:
                c.px(x, 4 + j, shade(roof, 0.18))
    c.ell(23.5, 17, 3.2, 3.2, rgb("#bfe6ff"))  # attic window
    c.rect(20, 31, 8, 15, rgb("#c9644a"))
    c.ell(23.5, 31, 4, 3, rgb("#c9644a"), top_only=True)
    c.dot(26, 39, rgb("#ffd24a"))
    for x in (9, 32):
        c.rect(x, 29, 7, 7, rgb("#bfe6ff"))
        c.rect(x + 3, 29, 1, 7, beam)
        c.rect(x - 1, 36, 9, 2, beam)  # flower box
        for i, colour in enumerate(("#ff8fb3", "#ffd24a", "#ff8fb3")):
            c.dot(x + 1 + i * 2, 35, rgb(colour))
    save(c.finish(), "home_2.png")


# assets/sprites/items/<id>.png for every GameState.ITEMS entry and every kind
# of debris: 16x16. Placed things and debris use the same picture on the
# ground, so each should sit on the bottom of its tile.

def make_things():
    wood, stone, green = rgb("#a8744a"), rgb("#aaa6b8"), rgb("#5aa85a")

    def log_pile(c):
        c.rect(2, 9, 12, 4, wood)
        c.rect(4, 5, 10, 4, light(wood, 0.12))
        for x, y in ((2, 9), (4, 5)):
            c.rect(x, y, 2, 4, rgb("#e3c48a"))

    def stones(c):
        c.ell(5.5, 11, 4, 3.4, stone)
        c.ell(10.5, 9.5, 4, 4.4, light(stone, 0.12))

    def fiber(c):
        straw = rgb("#b9d36a")
        c.rect(4, 2, 8, 12, straw)
        for x in (6, 9):
            c.rect(x, 2, 1, 12, shade(straw, 0.2))
        c.rect(3, 7, 10, 2, rgb("#c9644a"))

    def mulch(c):
        c.rect(3, 4, 10, 10, rgb("#8a5e3a"))
        c.rect(4, 2, 8, 2, rgb("#6b4630"))
        c.rect(5, 7, 6, 4, rgb("#5aa85a"))
        c.dot(7, 8, rgb("#fbeed3"))
        c.dot(8, 9, rgb("#fbeed3"))

    def path(c):
        c.rect(2, 3, 12, 10, stone)
        c.rect(1, 5, 14, 6, stone)
        c.rect(4, 5, 5, 1, light(stone, 0.3))
        c.rect(9, 10, 3, 1, shade(stone, 0.2))

    def fence(c):
        for x in (2, 12):
            c.rect(x, 3, 2, 12, wood)
            c.rect(x, 2, 2, 1, light(wood, 0.3))
        c.rect(0, 6, 16, 2, light(wood, 0.12))
        c.rect(0, 11, 16, 2, light(wood, 0.12))

    def sprinkler(c):
        metal = rgb("#8fb0c8")
        c.rect(7, 6, 2, 9, metal)
        c.rect(3, 5, 10, 2, metal)
        c.rect(6, 3, 4, 2, rgb("#5a7f9a"))
        c.rect(5, 14, 6, 1, rgb("#5a7f9a"))
        for x, y in ((2, 3), (13, 3), (1, 8), (14, 8)):
            c.dot(x, y, rgb("#5aa0e0"))

    def lantern(c):
        c.rect(7, 8, 2, 7, rgb("#6b5a4a"))
        c.rect(5, 14, 6, 1, rgb("#6b5a4a"))
        c.rect(5, 3, 6, 6, rgb("#ffe07a"))
        c.rect(4, 2, 8, 1, rgb("#6b5a4a"))
        c.rect(6, 1, 4, 1, rgb("#6b5a4a"))
        c.dot(7, 5, WHITE)

    def bowl(c, food, bits):
        c.ell(7.5, 9, 6, 4.5, rgb("#fbeed3"), bottom_only=True)
        c.rect(2, 8, 12, 2, food)
        c.ell(7.5, 8, 5, 2.5, food, top_only=True)
        for i, colour in enumerate(bits):
            c.dot(4 + i * 3, 7, rgb(colour))
            c.dot(5 + i * 3, 6, rgb(colour))

    def tea(c):
        c.rect(3, 6, 8, 7, rgb("#fbeed3"))
        c.rect(4, 7, 6, 2, rgb("#8f9bff"))
        c.rect(11, 7, 2, 1, rgb("#fbeed3"))
        c.rect(12, 8, 1, 3, rgb("#fbeed3"))
        c.rect(11, 11, 2, 1, rgb("#fbeed3"))
        c.dot(6, 3, WHITE)
        c.dot(7, 2, WHITE)
        c.dot(8, 4, WHITE)

    def pie(c):
        c.ell(7.5, 9, 6.5, 3.5, rgb("#e0a85a"))
        c.ell(7.5, 8, 5, 2.4, rgb("#f08a2e"))
        c.rect(1, 10, 14, 3, rgb("#c98a45"))
        c.dot(6, 8, rgb("#ffd35c"))
        c.dot(9, 7, rgb("#ffd35c"))

    def branch(c):
        for i in range(10):
            c.rect(3 + i, 12 - i // 2, 2, 2, wood)
        c.rect(8, 6, 2, 3, wood)
        c.rect(10, 5, 2, 2, green)

    def rock(c):
        c.ell(7.5, 10.5, 5.5, 4.2, stone)
        c.ell(6, 9, 2.5, 1.5, light(stone, 0.25))

    def weed(c):
        c.ell(7.5, 12, 5.5, 2.6, green)
        c.tri(4, 6, 1.8, 6, green)
        c.tri(8, 3, 2.0, 9, light(green, 0.2))
        c.tri(11.5, 7, 1.8, 5, green)

    drawings = {
        "wood": log_pile, "stone": stones, "fiber": fiber, "mulch": mulch, "path": path, "fence": fence,
        "sprinkler": sprinkler, "lantern": lantern, "tea": tea, "pie": pie,
        "salad": lambda c: bowl(c, rgb("#6fc46a"), ("#ffcf4a", "#ff8fb3", "#ffcf4a")),
        "stew": lambda c: bowl(c, rgb("#b5523f"), ("#f3e9d2", "#5fae6a", "#f3e9d2")),
        "branch": branch, "rock": rock, "weed": weed,
    }
    for name, draw in drawings.items():
        save(piece(16, 16, draw), "items", name + ".png")


# assets/sprites/tower.png: the clock tower, 32x48, base on the bottom row.
# Its clock face is left blank (centre 15.5, 20.5); the game draws the hands.

def make_tower():
    c = Canvas(32, 48)
    stone, roof, wood = rgb("#b9b3c4"), rgb("#7a5aa8"), rgb("#8a5e3a")
    c.rect(7, 12, 18, 34, stone)
    for y in range(16, 46, 6):
        c.rect(7, y, 18, 1, shade(stone, 0.18))
    for x, y in ((12, 13), (20, 19), (10, 31), (18, 37), (14, 43)):
        c.rect(x, y, 1, 3, shade(stone, 0.18))
    c.rect(5, 44, 22, 2, shade(stone, 0.25))  # step
    c.tri(15.5, 1, 12, 11, roof)
    c.rect(15, 0, 2, 2, rgb("#ffd24a"))  # finial
    c.ell(15.5, 20.5, 7.4, 7.4, wood)
    c.ell(15.5, 20.5, 6, 6, rgb("#fff6dc"))
    for dx, dy in ((0, -5), (5, 0), (0, 5), (-5, 0)):
        c.dot(15 + dx, 20 + dy, DARK)
        c.dot(16 + dx if dx == 0 else 15 + dx, 20 + dy if dx == 0 else 21 + dy, DARK)
    c.rect(12, 34, 8, 12, wood)  # door
    c.ell(15.5, 34, 4, 3, wood, top_only=True)
    c.dot(18, 40, rgb("#ffd24a"))
    c.rect(13, 29, 6, 2, rgb("#ffd24a"))  # bell slot
    save(c.finish(), "tower.png")


# ---------------------------------------------------------- inside the home
# assets/sprites/room_<level>.png: the whole room in one picture: two tile
# rows of wall, then the floor, with the furniture drawn in. Sizes and
# furniture places must match GameState.ROOMS.
# assets/sprites/blanket_<level>.png: 32x19, drawn over sleepers in the bed.

ROOM_SIZES = [(8, 5), (10, 6), (12, 7)]


def piece(w, h, draw):
    c = Canvas(w, h)
    draw(c)
    return c.finish()


def crate(c):
    c.rect(1, 3, 14, 12, rgb("#b98a55"))
    c.rect(1, 8, 14, 1, rgb("#8a6238"))
    c.rect(4, 3, 1, 12, rgb("#8a6238"))
    c.rect(11, 3, 1, 12, rgb("#8a6238"))


def lantern(c):
    c.rect(5, 6, 6, 8, rgb("#ffe07a"))
    c.rect(4, 5, 8, 1, rgb("#6b5a4a"))
    c.rect(4, 14, 8, 1, rgb("#6b5a4a"))
    c.rect(7, 2, 2, 3, rgb("#6b5a4a"))
    c.dot(7, 9, WHITE)
    c.dot(8, 10, WHITE)


def table(c):
    c.rect(1, 5, 14, 5, rgb("#b98a55"))
    c.rect(2, 10, 2, 5, rgb("#8a6238"))
    c.rect(12, 10, 2, 5, rgb("#8a6238"))
    c.rect(6, 1, 4, 4, rgb("#8fd0ff"))  # a little vase
    c.dot(7, 0, rgb("#ff8fb3"))
    c.dot(8, 0, rgb("#ffd24a"))


def drawers(c):
    c.rect(1, 4, 30, 11, rgb("#a8744a"))
    c.rect(1, 9, 30, 1, rgb("#7a5234"))
    c.rect(16, 4, 1, 11, rgb("#7a5234"))
    for x in (7, 23):
        c.rect(x, 6, 3, 1, rgb("#ffd24a"))
        c.rect(x, 12, 3, 1, rgb("#ffd24a"))


def pot_plant(c):
    c.rect(4, 16, 8, 7, rgb("#c9744a"))
    c.rect(3, 15, 10, 2, rgb("#dd8a5e"))
    c.ell(7.5, 9, 5.5, 6, rgb("#5aa85a"))
    c.ell(5, 6, 2.5, 3, rgb("#6fc46a"))


def nightstand(c):
    c.rect(2, 5, 12, 10, rgb("#a8744a"))
    c.rect(2, 9, 12, 1, rgb("#7a5234"))
    c.rect(7, 11, 2, 1, rgb("#ffd24a"))
    c.rect(6, 1, 4, 4, rgb("#ffe07a"))  # lamp


def fireplace(c):
    stone = rgb("#b9b3c4")
    c.rect(1, 0, 30, 31, stone)
    for y in range(4, 31, 6):
        c.rect(1, y, 30, 1, shade(stone, 0.2))
    c.rect(7, 13, 18, 18, rgb("#3a2a3a"))
    c.ell(15.5, 13, 9, 5, rgb("#3a2a3a"), top_only=True)
    c.tri(15.5, 17, 6, 12, rgb("#f08a2e"))
    c.tri(15.5, 22, 3.5, 7, rgb("#ffd24a"))
    c.rect(0, 0, 32, 3, rgb("#8a5e3a"))  # mantel


def bookshelf(c):
    c.rect(1, 0, 14, 23, rgb("#8a5e3a"))
    for y in (2, 9, 16):
        c.rect(3, y, 10, 5, rgb("#4a3424"))
        for i, colour in enumerate(("#e0605a", "#5aa0e0", "#ffd24a", "#5aa85a", "#e0739f")):
            c.rect(3 + i * 2, y + 1, 2, 4, rgb(colour))


def stove(c):
    c.rect(1, 3, 14, 12, rgb("#5a5a66"))
    c.rect(1, 3, 14, 2, rgb("#3a3a44"))
    c.rect(3, 8, 10, 5, rgb("#2e2a33"))
    c.rect(5, 10, 6, 2, rgb("#f08a2e"))
    c.rect(4, 1, 3, 2, rgb("#8a8a96"))  # a pot on top
    c.rect(10, 0, 2, 3, rgb("#3a3a44"))  # flue


def window(c):
    c.rect(1, 1, 14, 12, rgb("#8a5e3a"))
    c.rect(3, 3, 10, 8, rgb("#bfe6ff"))
    c.rect(7, 3, 2, 8, rgb("#8a5e3a"))
    c.rect(3, 6, 10, 1, rgb("#8a5e3a"))


def bed(level):
    def draw(c):
        if level == 0:  # two bedrolls side by side
            for x, colour in ((1, "#7fa8e0"), (17, "#e89ab8")):
                c.rect(x, 2, 14, 29, rgb("#e9dcc0"))
                c.rect(x + 2, 3, 10, 7, WHITE)
        else:
            frame = rgb("#8a5e3a") if level == 1 else rgb("#6b4630")
            c.rect(0, 0, 32, 32, frame)
            c.rect(2, 3, 28, 27, rgb("#f6efe2"))
            c.rect(4, 4, 10, 7, WHITE)
            c.rect(18, 4, 10, 7, WHITE)
            if level == 2:
                c.rect(0, 0, 32, 3, rgb("#8f6a48"))
    return piece(32, 32, draw)


def blanket(level):
    def draw(c):
        if level == 0:
            for x, colour in ((1, "#7fa8e0"), (17, "#e89ab8")):
                c.rect(x, 0, 14, 18, rgb(colour))
                c.rect(x, 0, 14, 2, light(rgb(colour), 0.4))
        elif level == 1:
            c.rect(2, 0, 28, 17, rgb("#d9605a"))
            c.rect(2, 0, 28, 3, WHITE)
            for x in range(4, 28, 8):
                for y in range(5, 15, 6):
                    c.rect(x, y, 4, 3, rgb("#f2b84a"))
        else:
            c.rect(2, 0, 28, 17, rgb("#5aa88a"))
            c.rect(2, 0, 28, 3, WHITE)
            for x in (6, 15, 24):
                for dx, dy in ((0, 0), (2, 0), (0, 1), (1, 1), (2, 1), (1, 2)):
                    c.dot(x + dx, 7 + dy, rgb("#ffd9ea"))
                    c.dot(x + dx - 4, 12 + dy, rgb("#ffd9ea"))
    return piece(32, 19, draw)


def make_rooms():
    for level, (w, h) in enumerate(ROOM_SIZES):
        width, height = w * 16, (h + 2) * 16
        room = Image.new("RGBA", (width, height), (0, 0, 0, 255))
        px = room.load()
        rng = random.Random(level + 40)
        for y in range(height):
            for x in range(width):
                if y < 32:  # wall
                    if level == 0:  # striped tent cloth
                        c = rgb("#f08a78") if (x // 8) % 2 == 0 else rgb("#fbe6c4")
                        c = shade(c, 0.12) if y > 27 else c
                    elif level == 1:  # logs
                        c = rgb("#a8744a")
                        c = shade(c, 0.28) if y % 8 == 7 else (light(c, 0.12) if y % 8 == 0 else c)
                    else:  # wallpaper over wood panelling
                        c = rgb("#cfe3c0")
                        if y >= 22:
                            c = rgb("#b98a55") if (x % 8) else rgb("#8a6238")
                        elif (x % 8 == 3 and y % 8 == 3):
                            c = rgb("#9fc79a")
                else:  # floor
                    fy = y - 32
                    if level == 0:  # woven mat
                        c = rgb("#dcbf8c")
                        if (x + (fy // 4) * 4) % 8 < 1 or fy % 4 == 3:
                            c = shade(c, 0.12)
                    else:  # planks
                        c = rgb("#c98f55") if level == 1 else rgb("#dfae6c")
                        row = fy // 8
                        if fy % 8 == 7 or (x + row * 11) % 32 == 0:
                            c = shade(c, 0.22)
                        elif fy % 8 == 0:
                            c = light(c, 0.1)
                px[x, y] = c + (255,)
        for _ in range(w * h // 3):  # a few floor specks
            x, y = rng.randrange(width), rng.randrange(34, height)
            px[x, y] = shade(px[x, y][:3], 0.1) + (255,)

        def put(img, cell_x, cell_y, dy=0):
            room.alpha_composite(img, (cell_x * 16, cell_y * 16 + dy))

        # Exit mat at the bottom middle, and a rug in the bigger homes.
        mat = piece(32, 8, lambda c: (c.rect(1, 1, 30, 6, rgb("#8a6238")), c.rect(3, 3, 26, 2, rgb("#c9a26a"))))
        put(mat, w // 2 - 1, h + 1, 8)
        if level >= 1:
            def rug(c):
                c.ell(23.5, 11.5, 22, 10, rgb("#e89a6a") if level == 1 else rgb("#7fb8d9"))
                c.ell(23.5, 11.5, 16, 6, rgb("#fbe6c4"))
            put(piece(48, 24, rug), w // 2 - 1, h - 1 if level == 1 else h - 2, 2)
        put(bed(level), 1, 2)
        if level == 0:
            put(piece(16, 16, crate), 6, 2)
            put(piece(16, 16, lantern), 7, 2)
        elif level == 1:
            put(piece(16, 16, window), 4, 0, 6)
            put(piece(16, 16, table), 5, 2)
            put(piece(16, 16, stove), 7, 2)
            put(piece(32, 16, drawers), 8, 2)
            put(piece(16, 24, pot_plant), 9, 7, -8)
        else:
            put(piece(16, 16, window), 5, 0, 4)
            put(piece(16, 16, window), 6, 0, 4)
            put(piece(16, 16, nightstand), 4, 2)
            put(piece(16, 16, stove), 6, 2)
            put(piece(32, 32, fireplace), 8, 1)
            put(piece(16, 24, bookshelf), 11, 2, -8)
            put(piece(16, 24, pot_plant), 11, 8, -8)
            put(piece(16, 24, pot_plant), 0, 8, -8)
        save(room, "room_%d.png" % level)
        save(blanket(level), "blanket_%d.png" % level)


# ------------------------------------------------------------ shop & items
# assets/sprites/stall.png: Bristle's market stall, 48x48, base on the bottom row.
# assets/sprites/keeper.png: Bristle's portrait for the shop screen, 32x32.
# assets/sprites/items/<id>.png and <id>_seeds.png: 16x16 icons per plant.

def bristle(c, cx, cy, scale=1.0):
    """A hedgehog shopkeeper centred on (cx, cy)."""
    quill, face = rgb("#7a5234"), rgb("#f3d9b0")
    c.ell(cx, cy, 8 * scale, 7 * scale, quill)
    for i in range(-3, 4):
        c.tri(cx + i * 2.4 * scale, cy - 10 * scale, 1.4 * scale, 4 * scale, quill)
    c.ell(cx, cy + 2 * scale, 5.5 * scale, 4.5 * scale, face)
    eye = max(1, int(scale))
    for side in (-1, 1):
        for dy in range(2 * eye):
            for dx in range(eye):
                c.dot(cx + side * 2.5 * scale + dx - 0.5, cy + 0.5 * scale + dy, DARK)
    c.dot(cx - 0.5, cy + 3.5 * scale, DARK)
    c.dot(cx + 0.5, cy + 3.5 * scale, DARK)


def make_stall():
    c = Canvas(48, 48)
    wood = rgb("#b98a55")
    c.rect(3, 12, 2, 34, rgb("#8a6238"))
    c.rect(43, 12, 2, 34, rgb("#8a6238"))
    bristle(c, 23.5, 25)
    c.rect(2, 31, 44, 15, wood)  # counter
    c.rect(2, 31, 44, 2, light(wood, 0.25))
    for x in range(8, 44, 9):
        c.rect(x, 34, 1, 12, shade(wood, 0.2))
    for x, colour in ((6, "#ffcf4a"), (12, "#ff8fb3"), (33, "#8f9bff")):  # seed packets
        c.rect(x, 26, 5, 6, rgb("#fbeed3"))
        c.dot(x + 2, 28, rgb(colour))
        c.dot(x + 2, 29, rgb(colour))
    c.rect(39, 27, 4, 5, rgb("#ffd24a"))  # coin jar
    for x in range(0, 48):  # striped awning with a scalloped edge
        stripe = rgb("#3fa7a0") if (x // 6) % 2 == 0 else rgb("#fbeed3")
        for y in range(3, 13 + (2 if (x % 6) in (2, 3) else (1 if (x % 6) in (1, 4) else 0))):
            c.px(x, y, stripe)
    save(c.finish(), "stall.png")
    portrait = Canvas(32, 32)
    bristle(portrait, 15.5, 17, 1.6)
    save(portrait.finish(), "keeper.png")


def make_items():
    for pid, (shape, stages, leaf, bloom, _radiant, accent) in PLANTS.items():
        frame = plant_frame(shape, "bloom", 1, rgb(leaf), rgb(bloom), rgb(accent), random.Random(pid))
        box = frame.getbbox()
        top = min(box[1], 8)
        save(frame.crop((0, top, 16, top + 16)), "items", pid + ".png")
        packet = Canvas(16, 16)
        packet.rect(3, 2, 10, 13, rgb("#fbeed3"))
        packet.rect(3, 2, 10, 2, rgb("#d9c39a"))
        packet.ell(7.5, 9.5, 3, 3, rgb(bloom))
        packet.dot(7, 9, light(rgb(bloom), 0.5))
        packet.rect(7, 13, 2, 1, rgb(leaf))
        save(packet.finish(), "items", pid + "_seeds.png")


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


# --------------------------------------------------------------- UI icons
# assets/sprites/ui_icons.png: 12x12 frames left to right:
#   hoe, watering can, seed bag, petting hand (heart), basket,
#   sun, rain cloud, snow cloud, moon, love heart, coin

def icon(draw):
    c = Canvas(12, 12)
    draw(c)
    return c.finish()


def make_icons():
    wood, metal, blue = rgb("#9a6a42"), rgb("#c9ccd6"), rgb("#5aa0e0")
    cloud, sun = rgb("#dfe6f0"), rgb("#ffd24a")

    def hoe(c):
        for i in range(7):
            c.rect(2 + i, 9 - i, 2, 1, wood)
        c.rect(6, 2, 4, 2, metal)
        c.rect(9, 3, 1, 3, metal)

    def can(c):
        c.rect(3, 5, 5, 5, blue)
        c.rect(8, 6, 1, 2, blue)
        c.rect(9, 4, 1, 3, blue)
        c.rect(10, 3, 1, 2, blue)
        c.rect(1, 6, 2, 1, blue)
        c.rect(1, 7, 1, 2, blue)
        c.rect(4, 3, 3, 1, blue)

    def seeds(c):
        c.rect(3, 5, 6, 5, rgb("#e3c48a"))
        c.rect(4, 4, 4, 1, rgb("#e3c48a"))
        c.rect(5, 2, 2, 2, rgb("#e3c48a"))
        c.rect(4, 3, 4, 1, rgb("#c9644a"))
        c.dot(5, 7, rgb("#4da355"))
        c.dot(6, 6, rgb("#4da355"))
        c.dot(6, 7, rgb("#4da355"))
        c.dot(6, 8, rgb("#4da355"))

    def heart(c, colour=rgb("#ff7fa8")):
        for x, y, w in ((2, 3, 3), (7, 3, 3), (1, 4, 10), (1, 5, 10), (2, 6, 8), (3, 7, 6), (4, 8, 4), (5, 9, 2)):
            c.rect(x, y, w, 1, colour)

    def basket(c):
        c.rect(2, 6, 8, 2, rgb("#c08a4e"))
        c.rect(3, 8, 6, 2, rgb("#c08a4e"))
        c.rect(3, 3, 1, 3, wood)
        c.rect(8, 3, 1, 3, wood)
        c.rect(4, 2, 4, 1, wood)
        c.dot(4, 5, rgb("#ff7fa8"))
        c.dot(6, 5, rgb("#ffd24a"))
        c.dot(7, 5, rgb("#8f9bff"))

    def sunny(c):
        c.ell(5.5, 5.5, 3.2, 3.2, sun)
        for x, y in ((5, 0), (6, 0), (5, 11), (6, 11), (0, 5), (0, 6), (11, 5), (11, 6), (1, 1), (10, 1), (1, 10), (10, 10)):
            c.dot(x, y, sun)

    def cloudy(c, drops):
        c.ell(4, 5, 3, 2.4, cloud)
        c.ell(7.5, 4.2, 3, 2.8, cloud)
        c.rect(2, 5, 8, 2, cloud)
        for x, y in ((3, 9), (6, 10), (9, 9)):
            c.dot(x, y, drops)
            if drops != WHITE:
                c.dot(x, y - 1, drops)

    def moon(c):
        c.ell(5.5, 5.5, 3.6, 3.6, rgb("#f3ecc8"))
        c.ell(7.5, 4.5, 3.0, 3.0, None)

    def coin(c):
        c.ell(5.5, 5.5, 4.6, 4.6, rgb("#f2b84a"))
        c.ell(5.5, 5.5, 2.6, 2.6, rgb("#ffe07a"))
        c.dot(4, 4, WHITE)

    draws = [hoe, can, seeds, heart, basket, sunny, lambda c: cloudy(c, blue), lambda c: cloudy(c, WHITE), moon,
             lambda c: heart(c, rgb("#ff5d7a")), coin]
    save(sheet([icon(d) for d in draws]), "ui_icons.png")


# assets/sprites/icon.png: the game's window icon, a Sunpuff on parchment.

def make_app_icon():
    shape, _stages, leaf, bloom, _radiant, accent = PLANTS["sunpuff"]
    flower = plant_frame(shape, "bloom", 1, rgb(leaf), rgb(bloom), rgb(accent), random.Random(1))
    tile = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    card = Canvas(32, 32)
    card.rect(1, 1, 30, 30, rgb("#fae8bd"))
    card.rect(1, 25, 30, 6, rgb("#79c267"))
    tile.alpha_composite(card.finish(shading=False))
    tile.alpha_composite(flower, (8, 5))
    save(tile.resize((128, 128), Image.NEAREST), "icon.png")


if __name__ == "__main__":
    make_app_icon()
    make_icons()
    make_plants()
    make_players()
    make_hats()
    make_tiles()
    make_tent()
    make_cabin()
    make_cottage()
    make_rooms()
    make_stall()
    make_tower()
    make_things()
    make_items()
    make_tree()
    print("sprites written to", os.path.normpath(OUT))
