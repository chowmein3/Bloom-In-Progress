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
    "skybell": ("flower", 3, "#4f9e6a", "#6fb8ff", "#d6ecff", "#3f7fd1"),
    "snapvine": ("bush", 3, "#5aa85a", "#c8e05a", "#f3ffb0", "#7fb83a"),
    "blazestar": ("flower", 3, "#4a9a4a", "#ff6a3a", "#ffc46a", "#d9443a"),
    "melonbub": ("gourd", 4, "#4f9a4c", "#7fd08a", "#d6ffb8", "#3f8f5a"),
    "amberleaf": ("tulip", 3, "#8a9a4a", "#f2a23a", "#ffe08a", "#c9741c"),
    "duskberry": ("bush", 3, "#4a6a5a", "#8a4ac8", "#e0a8ff", "#5a2f8f"),
    "glimmercap": ("mushroom", 3, "#8aa3a0", "#5ad0c8", "#b8fff3", "#eef6f3"),
    "icebloom": ("tulip", 3, "#7fb0c0", "#d6f3ff", "#ffffff", "#9fd0ea"),
    "wheat": ("grain", 3, "#9fb04a", "#e8c45a", "#fff0a8", "#c99a2e"),
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
    elif shape == "grain":
        for x, top in ((4, 7), (7, 4), (10, 6)):
            c.rect(x, top + 5, 2, GROUND - top - 4, leaf)
            if not resting:
                c.rect(x - 1, top, 4, 6, bloom)
                c.rect(x, top - 1, 2, 1, bloom)
                c.dot(x, top + 2, accent)
                c.dot(x + 1, top + 4, accent)
        c.face(6, 15)
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
# GameState.HAT_ORDER (straw, flower, sprout, beanie, sun, laurel). A hat is drawn
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

    def laurel(c):
        gold = rgb("#ffd24a")
        for x in (3, 5, 9, 11):
            c.rect(x, 4, 2, 2, gold)
        c.rect(2, 5, 12, 1, gold)
        c.rect(7, 2, 2, 2, light(gold, 0.4))

    frames = []
    for draw in (straw, flower, sprout, beanie, sun, laurel):
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

    def fish(body, belly, fin):
        def draw(c):
            c.ell(7, 8.5, 5.5, 3.4, rgb(body))
            c.ell(7, 10, 4, 1.6, rgb(belly))
            c.tri(13.5, 5, 2.2, 4, rgb(fin))
            c.rect(12, 7, 3, 4, rgb(fin))
            c.rect(6, 4, 3, 2, rgb(fin))
            c.dot(3, 8, DARK)
        return draw

    def fern(c):
        c.rect(5, 11, 6, 4, rgb("#c9744a"))
        c.rect(4, 10, 8, 1, rgb("#dd8a5e"))
        c.ell(7.5, 6, 5.5, 4.5, green)
        c.ell(5, 4, 2, 2, light(green, 0.25))

    def lamp(c):
        c.rect(7, 6, 2, 8, rgb("#6b5a4a"))
        c.rect(4, 14, 8, 1, rgb("#6b5a4a"))
        c.tri(7.5, 1, 5, 6, rgb("#ffe07a"))
        c.rect(3, 6, 10, 1, rgb("#f2b84a"))

    def rug(c):
        c.ell(7.5, 8, 7.4, 5.5, rgb("#d9605a"))
        c.ell(7.5, 8, 5, 3.4, rgb("#fbe6c4"))
        c.ell(7.5, 8, 2.4, 1.4, rgb("#d9605a"))

    def armchair(c):
        seat = rgb("#5a9ac8")
        c.rect(2, 3, 12, 8, seat)
        c.rect(1, 7, 3, 7, light(seat, 0.15))
        c.rect(12, 7, 3, 7, light(seat, 0.15))
        c.rect(4, 9, 8, 4, light(seat, 0.3))
        c.rect(3, 14, 2, 1, wood)
        c.rect(11, 14, 2, 1, wood)

    def teatable(c):
        c.ell(7.5, 7, 6.5, 3, rgb("#b98a55"))
        c.rect(7, 9, 2, 5, wood)
        c.rect(4, 14, 8, 1, wood)
        c.rect(4, 4, 3, 3, WHITE)
        c.rect(9, 4, 3, 3, WHITE)

    def bookcase(c):
        c.rect(2, 1, 12, 14, rgb("#8a5e3a"))
        for y in (3, 9):
            c.rect(3, y, 10, 4, rgb("#4a3424"))
            for i, colour in enumerate(("#e0605a", "#5aa0e0", "#ffd24a", "#5aa85a", "#e0739f")):
                c.rect(3 + i * 2, y + 1, 2, 3, rgb(colour))

    def gnome(c):
        c.tri(7.5, 1, 4, 6, rgb("#d9443a"))
        c.rect(5, 7, 6, 3, rgb("#ffd9b8"))
        c.rect(4, 9, 8, 3, WHITE)
        c.rect(5, 12, 6, 3, rgb("#4f7fd1"))
        c.dot(6, 8, DARK)
        c.dot(9, 8, DARK)

    def birdbath(c):
        c.ell(7.5, 5, 6.5, 2.6, stone)
        c.ell(7.5, 4.5, 4.5, 1.4, rgb("#8fd0ff"))
        c.rect(6, 7, 4, 6, stone)
        c.rect(4, 13, 8, 2, stone)

    def skewer(c):
        for i in range(12):
            c.px(2 + i, 13 - i, wood)
        c.ell(6, 9.5, 2.6, 2.2, rgb("#e89a6a"))
        c.ell(10, 5.5, 2.6, 2.2, rgb("#e89a6a"))

    def crate_bin(c):
        c.rect(1, 5, 14, 10, wood)
        c.rect(1, 9, 14, 1, shade(wood, 0.25))
        c.rect(0, 3, 16, 3, light(wood, 0.2))  # lid, propped open
        c.rect(5, 11, 6, 2, rgb("#ffd24a"))  # a coin plate

    def scarecrow(c):
        c.rect(7, 6, 2, 9, wood)
        c.rect(2, 7, 12, 2, wood)
        c.rect(4, 7, 8, 5, rgb("#c9644a"))
        c.ell(7.5, 4, 3, 2.6, rgb("#e3c48a"))
        c.rect(4, 1, 8, 1, rgb("#8a5e3a"))
        c.rect(6, 0, 4, 1, rgb("#8a5e3a"))
        c.dot(6, 4, DARK)
        c.dot(9, 4, DARK)

    def bigsprinkler(c):
        metal = rgb("#e0b04a")
        c.rect(7, 5, 2, 10, metal)
        c.rect(2, 4, 12, 2, metal)
        c.rect(7, 1, 2, 4, metal)
        c.rect(5, 14, 6, 1, rgb("#a87a2a"))
        for x, y in ((1, 2), (14, 2), (0, 7), (15, 7), (4, 0), (11, 0)):
            c.dot(x, y, rgb("#5aa0e0"))

    def sapling(c):
        c.rect(7, 8, 2, 7, wood)
        c.ell(7.5, 5.5, 4, 3.6, green)
        c.rect(5, 14, 6, 1, rgb("#8a6238"))

    def feed(c):
        c.rect(3, 5, 10, 9, rgb("#e3c48a"))
        c.rect(4, 3, 8, 2, rgb("#c9a26a"))
        for x, y in ((5, 8), (8, 7), (10, 10), (6, 11)):
            c.dot(x, y, rgb("#f2b84a"))

    def plumble(c):
        c.ell(7.5, 9, 5, 4.6, rgb("#b05ac8"))
        c.ell(6, 7.5, 1.6, 1.4, rgb("#d99aea"))
        c.rect(7, 2, 2, 3, wood)
        c.rect(9, 3, 3, 2, green)

    def egg(c):
        c.ell(7.5, 9, 4.2, 5.2, rgb("#fbeed3"))
        c.ell(6, 7, 1.4, 1.8, WHITE)

    def milk(c):
        c.rect(5, 5, 6, 10, WHITE)
        c.rect(6, 2, 4, 3, WHITE)
        c.rect(6, 1, 4, 1, rgb("#5aa0e0"))
        c.rect(5, 9, 6, 3, rgb("#5aa0e0"))

    def nugget(colour):
        def draw(c):
            c.ell(6, 10, 4, 3.2, rgb(colour))
            c.ell(10.5, 8.5, 3.4, 3.6, light(rgb(colour), 0.2))
            c.dot(5, 9, WHITE)
        return draw

    def amethyst(c):
        gem = rgb("#a86ae0")
        c.tri(5, 4, 3, 9, gem)
        c.tri(10, 2, 3.4, 11, light(gem, 0.2))
        c.rect(2, 12, 12, 2, shade(gem, 0.2))

    def ore_rock(vein):
        def draw(c):
            c.ell(7.5, 9.5, 7, 5.6, rgb("#7d7888"))
            c.ell(5, 7, 3, 2, rgb("#958fa3"))
            if vein:
                for x, y in ((4, 9), (9, 7), (11, 11), (7, 12)):
                    c.rect(x, y, 2, 2, rgb(vein))
        return draw

    def cup(colour):
        def draw(c):
            c.rect(3, 6, 8, 7, rgb("#fbeed3"))
            c.rect(4, 7, 6, 2, rgb(colour))
            c.rect(11, 7, 2, 1, rgb("#fbeed3"))
            c.rect(12, 8, 1, 3, rgb("#fbeed3"))
            c.rect(11, 11, 2, 1, rgb("#fbeed3"))
            c.dot(6, 3, WHITE)
            c.dot(8, 4, WHITE)
        return draw

    def omelette(c):
        c.ell(7.5, 10, 6.5, 3.5, WHITE)
        c.ell(7.5, 9, 5, 2.6, rgb("#ffd24a"))
        c.dot(6, 8, rgb("#5aa85a"))
        c.dot(9, 9, rgb("#e0605a"))

    def chicken(c):
        c.ell(7, 10, 5, 4, WHITE)
        c.ell(11, 6.5, 2.6, 2.6, WHITE)
        c.rect(11, 3, 2, 2, rgb("#e0605a"))
        c.rect(13, 7, 2, 1, rgb("#f2b84a"))
        c.dot(11, 6, DARK)
        c.rect(5, 14, 1, 1, rgb("#f2b84a"))
        c.rect(8, 14, 1, 1, rgb("#f2b84a"))

    def cow(c):
        c.rect(1, 6, 11, 7, WHITE)
        c.rect(3, 7, 3, 3, rgb("#5a4a42"))
        c.rect(8, 9, 2, 3, rgb("#5a4a42"))
        c.rect(11, 4, 4, 5, WHITE)
        c.rect(12, 8, 3, 2, rgb("#ffb3a8"))
        c.dot(13, 6, DARK)
        c.rect(11, 3, 1, 1, rgb("#e3c48a"))
        c.rect(14, 3, 1, 1, rgb("#e3c48a"))
        for x in (2, 5, 8, 10):
            c.rect(x, 13, 1, 2, rgb("#5a4a42"))

    def jar(c):
        c.rect(4, 5, 8, 10, rgb("#bfe6ff"))
        c.rect(5, 8, 6, 6, rgb("#e0605a"))
        c.rect(4, 3, 8, 2, rgb("#c9a26a"))

    def press(c):
        c.rect(2, 9, 12, 6, wood)
        c.rect(7, 2, 2, 7, metal_c)
        c.rect(4, 2, 8, 2, metal_c)
        c.rect(4, 7, 8, 2, rgb("#b05ac8"))

    def cheesepress(c):
        c.rect(2, 8, 12, 7, wood)
        c.rect(3, 4, 10, 4, rgb("#ffd24a"))
        c.rect(7, 1, 2, 3, metal_c)
        c.dot(5, 5, rgb("#f2b84a"))
        c.dot(10, 6, rgb("#f2b84a"))

    def beehive(c):
        for i, w in enumerate((6, 10, 12, 12, 10)):
            c.rect(8 - w // 2, 3 + i * 2, w, 2, rgb("#f2b84a") if i % 2 == 0 else rgb("#e0a03a"))
        c.rect(3, 13, 10, 2, wood)
        c.rect(7, 9, 2, 2, DARK)

    def pot(colour):
        def draw(c):
            c.rect(4, 6, 8, 9, rgb("#fbeed3"))
            c.rect(5, 8, 6, 5, rgb(colour))
            c.rect(4, 4, 8, 2, rgb("#c9644a"))
        return draw

    def cheese(c):
        c.tri(7.5, 4, 7, 6, rgb("#ffd24a"))
        c.rect(1, 9, 14, 5, rgb("#f2b84a"))
        c.dot(5, 11, rgb("#e0a03a"))
        c.dot(10, 12, rgb("#e0a03a"))

    def sprig(leaf_c, dot_c):
        def draw(c):
            c.ell(5, 10, 3, 4, rgb(leaf_c))
            c.ell(10, 9, 3, 4.5, light(rgb(leaf_c), 0.15))
            c.rect(7, 11, 2, 4, rgb(leaf_c))
            if dot_c:
                for x, y in ((5, 8), (10, 7), (8, 11)):
                    c.rect(x, y, 2, 2, rgb(dot_c))
        return draw

    def mailbox(c):
        c.rect(7, 8, 2, 7, wood)
        c.rect(3, 3, 10, 6, rgb("#5aa0e0"))
        c.rect(3, 3, 10, 1, light(rgb("#5aa0e0"), 0.3))
        c.rect(12, 1, 1, 4, rgb("#e0605a"))
        c.rect(12, 1, 3, 2, rgb("#e0605a"))

    def board(c):
        c.rect(1, 2, 14, 9, rgb("#b98a55"))
        c.rect(2, 11, 2, 4, wood)
        c.rect(12, 11, 2, 4, wood)
        for x, y, colour in ((3, 3, "#fbeed3"), (8, 4, "#ffe9a8"), (5, 7, "#d6ecff")):
            c.rect(x, y, 4, 3, rgb(colour))

    def apple(c):
        c.ell(7.5, 9, 5, 4.8, rgb("#e0443a"))
        c.ell(6, 7.5, 1.6, 1.4, rgb("#ff8a7a"))
        c.rect(7, 2, 2, 3, wood)
        c.rect(9, 3, 3, 2, green)

    def banana(c):
        yellow = rgb("#ffd84a")
        for i in range(9):
            c.rect(3 + i, 11 - abs(4 - i) // 1 + (1 if i in (0, 8) else 0) - 2, 2, 3, yellow)
        c.rect(2, 7, 2, 2, wood)
        c.rect(12, 7, 2, 1, rgb("#8a6238"))

    def sack(colour, mark):
        def draw(c):
            c.rect(3, 5, 10, 10, rgb(colour))
            c.rect(4, 3, 8, 2, shade(rgb(colour), 0.15))
            c.rect(5, 8, 6, 4, rgb(mark))
        return draw

    def butter(c):
        c.rect(2, 7, 12, 6, rgb("#ffe07a"))
        c.rect(2, 7, 12, 2, rgb("#fff3b8"))
        c.rect(1, 13, 14, 1, rgb("#bfe6ff"))

    def cinnamon(c):
        for y in (5, 8, 11):
            c.rect(2, y, 12, 2, rgb("#a8602e"))
            c.rect(2, y, 2, 2, rgb("#c9844a"))

    def oven(c):
        c.rect(1, 2, 14, 13, rgb("#c9c2c8"))
        c.rect(1, 2, 14, 3, rgb("#8f8894"))
        for x in (3, 7, 11):
            c.dot(x, 3, rgb("#e0605a"))
        c.rect(3, 7, 10, 6, rgb("#3a2a3a"))
        c.rect(4, 9, 8, 3, rgb("#f08a2e"))
        c.rect(3, 6, 10, 1, rgb("#6b5a6a"))

    def loaf(c):
        c.ell(7.5, 8, 6.5, 4, rgb("#c98a45"))
        c.rect(1, 9, 14, 5, rgb("#b0703a"))
        for x in (4, 7, 10):
            c.rect(x, 5, 1, 3, rgb("#ffe07a"))

    def applepie(c):
        c.ell(7.5, 9, 6.5, 3.5, rgb("#e0a85a"))
        c.ell(7.5, 8, 5, 2.4, rgb("#f2c46a"))
        c.rect(1, 10, 14, 3, rgb("#c98a45"))
        for x, y in ((5, 8), (8, 7), (10, 8)):
            c.dot(x, y, rgb("#e0443a"))

    def buns(c):
        for x, y in ((5, 10), (10.5, 9)):
            c.ell(x, y, 4, 3.6, rgb("#d9a05a"))
            c.ell(x, y, 2.2, 1.8, rgb("#fff3dc"))
            c.dot(int(x), int(y), rgb("#a8602e"))

    def young(fruit_c):
        def draw(c):
            c.rect(7, 8, 2, 7, wood)
            c.ell(7.5, 5.5, 4, 3.6, green)
            c.rect(5, 14, 6, 1, rgb("#8a6238"))
            c.rect(9, 5, 2, 2, rgb(fruit_c))
        return draw

    metal_c = rgb("#8fb0c8")
    drawings = {
        "apple": apple, "banana": banana, "flour": sack("#fbeed3", "#e3c48a"), "sugar": sack("#ffffff", "#ff8fb3"),
        "butter": butter, "cinnamon": cinnamon, "oven": oven, "bananabread": loaf, "applepie": applepie,
        "cinnamonbuns": buns, "applesapling": young("#e0443a"), "bananasapling": young("#ffd84a"),
        "jar": jar, "press": press, "cheesepress": cheesepress, "beehive": beehive,
        "jam": pot("#e0605a"), "honey": pot("#f2b84a"), "juice": pot("#b05ac8"), "cheese": cheese,
        "wildgreens": sprig("#5aa85a", None), "sunberry": sprig("#5aa85a", "#ff8a3a"),
        "chestnut": sprig("#8a6238", "#c9a26a"), "frostroot": sprig("#9fd0ea", "#ffffff"),
        "mailbox": mailbox, "board": board,
        "scarecrow": scarecrow, "bigsprinkler": bigsprinkler, "sapling": sapling, "feed": feed,
        "plumble": plumble, "egg": egg, "milk": milk, "copper": nugget("#d98a4a"), "goldore": nugget("#ffd24a"),
        "amethyst": amethyst, "omelette": omelette, "cocoa": cup("#8a5e3a"),
        "ore_stone": ore_rock(None), "ore_copper": ore_rock("#d98a4a"), "ore_gold": ore_rock("#ffd24a"), "ore_gem": ore_rock("#c88af0"),
        "chicken": chicken, "cow": cow,
        "minnow": fish("#9fb4c8", "#e3ecf2", "#7a94ad"),
        "sunfish": fish("#f2b84a", "#fff3b8", "#e0803a"),
        "raincarp": fish("#5a8fc8", "#bfe6ff", "#3f6a9a"),
        "moonfin": fish("#7a6ac8", "#e3d8ff", "#4f418f"),
        "frostfin": fish("#bfe9ff", "#ffffff", "#7fbfe6"),
        "goldie": fish("#ffd24a", "#fff6c9", "#f08a2e"),
        "fern": fern, "lamp": lamp, "rug": rug, "armchair": armchair, "teatable": teatable,
        "bookcase": bookcase, "gnome": gnome, "birdbath": birdbath, "skewer": skewer, "bin": crate_bin,
        "supper": lambda c: bowl(c, rgb("#7a6ac8"), ("#f3e9d2", "#e8584f", "#f3e9d2")),
        "wood": log_pile, "stone": stones, "fiber": fiber, "mulch": mulch, "path": path, "fence": fence,
        "sprinkler": sprinkler, "lantern": lantern, "tea": tea, "pie": pie,
        "salad": lambda c: bowl(c, rgb("#6fc46a"), ("#ffcf4a", "#ff8fb3", "#ffcf4a")),
        "stew": lambda c: bowl(c, rgb("#b5523f"), ("#f3e9d2", "#5fae6a", "#f3e9d2")),
        "branch": branch, "rock": rock, "weed": weed,
    }
    for name, draw in drawings.items():
        save(piece(16, 16, draw), "items", name + ".png")


# assets/sprites/fruit_tree.png: three 32x40 frames (young, grown, with fruit),
# base on the bottom row. coop.png and barn.png: 48x40. mine.png: 32x32.
# villager_<id>.png: 16x24, standing, facing down.

def make_farmyard():
    bark = rgb("#8a6044")
    # fruit_tree_<fruit>.png for each kind of fruit tree.
    for fruit, leaf_c, fruit_c in (("plumble", "#57a868", "#b05ac8"), ("apple", "#4f9e5a", "#e0443a"), ("banana", "#7fc46a", "#ffd84a")):
        leaf = rgb(leaf_c)
        frames = []
        for stage in range(3):
            c = Canvas(32, 40)
            if stage == 0:
                c.rect(15, 26, 2, 12, bark)
                c.ell(15.5, 22, 6, 6, leaf)
            else:
                c.rect(14, 22, 4, 16, bark)
                c.ell(15.5, 14, 12, 11, leaf)
                c.ell(8, 19, 6, 5, leaf)
                c.ell(23, 19, 6, 5, leaf)
                if stage == 2:
                    for x, y in ((8, 12), (20, 9), (13, 18), (23, 17), (15, 6)):
                        c.ell(x, y, 2, 2, rgb(fruit_c))
            frames.append(c.finish())
        save(sheet(frames), "fruit_tree_%s.png" % fruit)

    def building(wall, roof, door, name):
        c = Canvas(48, 40)
        c.rect(5, 18, 38, 20, rgb(wall))
        for y in range(22, 38, 5):
            c.rect(5, y, 38, 1, shade(rgb(wall), 0.2))
        c.tri(23.5, 2, 24, 17, rgb(roof))
        c.rect(19, 24, 10, 14, rgb(door))
        c.rect(23, 24, 1, 14, shade(rgb(door), 0.3))
        c.rect(33, 23, 6, 5, rgb("#bfe6ff"))
        save(c.finish(), name)

    building("#e8c48a", "#c9644a", "#8a5e3a", "coop.png")
    building("#c9544a", "#6b4630", "#fbeed3", "barn.png")

    c = Canvas(32, 32)
    rock = rgb("#7d7888")
    c.ell(15.5, 20, 15, 12, rock)
    c.rect(1, 20, 30, 10, rock)
    c.ell(15.5, 22, 8, 9, rgb("#241a2a"))
    c.rect(8, 22, 16, 8, rgb("#241a2a"))
    c.rect(6, 8, 3, 2, rgb("#958fa3"))
    c.rect(22, 11, 4, 2, rgb("#958fa3"))
    c.rect(9, 29, 14, 1, rgb("#8a5e3a"))
    save(c.finish(), "mine.png")

    looks = {  # body, head, extra drawing
        "maple": ("#f2b84a", "#c98a55"),
        "pebble": ("#5aa0e0", "#7fc46a"),
        "thistle": ("#8a9a5a", "#e9e4dc"),
    }
    for who, (clothes, face) in looks.items():
        c = Canvas(16, 24)
        c.rect(4, 20, 3, 3, rgb("#6b4a36"))
        c.rect(9, 20, 3, 3, rgb("#6b4a36"))
        c.rect(4, 13, 8, 7, rgb(clothes))
        c.rect(3, 13, 1, 5, rgb(clothes))
        c.rect(12, 13, 1, 5, rgb(clothes))
        c.rect(4, 6, 8, 7, rgb(face))
        if who == "maple":  # a bear in a beekeeper's hat
            c.rect(3, 4, 3, 3, rgb(face))
            c.rect(10, 4, 3, 3, rgb(face))
            c.rect(2, 5, 12, 1, rgb("#fff0c9"))
            c.rect(6, 10, 4, 3, rgb("#f3d9b0"))
        elif who == "pebble":  # a frog with a fishing cap
            c.rect(4, 4, 3, 3, rgb(face))
            c.rect(9, 4, 3, 3, rgb(face))
            c.rect(3, 6, 10, 1, rgb("#e0605a"))
            c.rect(5, 11, 6, 1, shade(rgb(face), 0.3))
        else:  # an old goat with a beard
            c.rect(3, 5, 2, 3, rgb("#c9c2b5"))
            c.rect(11, 5, 2, 3, rgb("#c9c2b5"))
            c.rect(6, 12, 4, 3, WHITE)
            c.rect(4, 5, 8, 1, rgb("#8a6238"))
        c.face(5, 8, happy=False, gap=5)
        save(c.finish(), "villager_%s.png" % who)


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
#   sun, rain cloud, snow cloud, moon, love heart, coin, fishing rod, pickaxe

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

    def rod(c):
        for i in range(9):
            c.rect(1 + i, 10 - i, 2, 1, wood)
        c.rect(10, 2, 1, 7, rgb("#dfe6f0"))  # line
        c.rect(9, 9, 2, 2, rgb("#e0605a"))  # float

    def pickaxe(c):
        for i in range(7):
            c.rect(2 + i, 9 - i, 2, 1, wood)
        c.rect(4, 2, 7, 2, metal)
        c.rect(3, 3, 2, 2, metal)
        c.rect(10, 3, 2, 3, metal)

    draws = [hoe, can, seeds, heart, basket, sunny, lambda c: cloudy(c, blue), lambda c: cloudy(c, WHITE), moon,
             lambda c: heart(c, rgb("#ff5d7a")), coin, rod, pickaxe]
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


# ------------------------------------------------------------- scenery
# assets/sprites/scenery/<kind>.png: the land's own trees, bushes, boulders,
# stumps, logs and fences. Four frames left to right, one per season
# (spring, summer, fall, winter); each stands on the bottom row, centred.
#   oak, cherry 32x44   maple, pine 32x48   birch 24x46   apple 32x44
#   bush, boulder, stump 16x16   log 32x16 (two tiles)   fence 16x16
# assets/sprites/scenery/cliff.png: 16x40 pieces (8 rows of grassy lip, then
#   a 32 row rock face), columns: face, face, left end, right end; one row per
#   season.
# assets/sprites/scenery/canopy_<season>.png: 128x128 tileable deep forest.
# assets/sprites/scenery/canopy_edge.png: 48x44 leafy crowns that round off
#   the forest's edge: six shapes across, one row per season.
# assets/sprites/scenery/trail.png: 16x16 dirt trail pieces, column = which
#   sides join another trail piece (1 up, 2 right, 4 down, 8 left), row =
#   season.

BARK = rgb("#7a5234")
SNOW = rgb("#f4f8ff")


def line(c, x0, y0, x1, y1, col, width=1):
    steps = int(max(abs(x1 - x0), abs(y1 - y0))) + 1
    for i in range(steps + 1):
        t = i / max(steps, 1)
        x, y = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
        c.rect(round(x - (width - 1) / 2), round(y), width, 1, col)


def bare_branches(c, cx, base, top, spread, bark, snow):
    """Winter: a trunk's branches with a little snow along their tops."""
    line(c, cx, base, cx, top + 6, bark, 2)
    for (dx, dy, ex, ey) in ((0, 0.55, -spread, 0.3), (0, 0.45, spread, 0.2), (0, 0.75, -spread * 0.7, 0.62),
                             (0, 0.7, spread * 0.75, 0.55), (0, 0.3, -spread * 0.4, 0.05), (0, 0.3, spread * 0.45, 0.02)):
        y0 = top + (base - top) * dy
        y1 = top + (base - top) * ey
        line(c, cx + dx, y0, cx + ex, y1, bark, 1)
        if snow:
            c.dot(round(cx + ex * 0.7), round(y0 + (y1 - y0) * 0.7) - 1, SNOW)
            c.dot(round(cx + ex), round(y1) - 1, SNOW)


def leafy(c, blobs, col, rng, spots=None, spot_n=0):
    """A canopy built up from leaf clumps: a darker mass, then clumps that get
    lighter towards the top, then spots (blossom, fruit or turning leaves)."""
    for (x, y, rx, ry) in blobs:
        c.ell(x, y, rx, ry, shade(col, 0.12))
    top = min(y - ry for (x, y, rx, ry) in blobs)
    bottom = max(y + ry for (x, y, rx, ry) in blobs)
    clumps = []
    for (x, y, rx, ry) in blobs:
        for _ in range(int(rx * ry / 9) + 2):
            a = rng.uniform(0, 6.283)
            d = rng.uniform(0, 0.75)
            clumps.append((x + math.cos(a) * rx * d, y + math.sin(a) * ry * d - 1, rng.uniform(2.6, 4.2)))
    clumps.sort(key=lambda k: k[1])
    for (x, y, r) in clumps:
        if c.p[min(max(int(y), 0), c.h - 1)][min(max(int(x), 0), c.w - 1)] is None:
            continue
        height = (y - top) / max(bottom - top, 1)
        tone = light(col, 0.16) if height < 0.35 else (col if height < 0.7 else shade(col, 0.06))
        c.ell(x, y, r, r * 0.85, tone)
    for _ in range(int(len(clumps) * 1.5)):  # leaf texture, stamped after shading
        x, y = rng.randrange(c.w), rng.randrange(c.h)
        if c.p[y][x] is not None and c.p[y][x] != BARK:
            c.dot(x, y, light(c.p[y][x], 0.25) if rng.random() < 0.5 else shade(c.p[y][x], 0.2))
    if spots:
        placed, tries = 0, 0
        while placed < spot_n and tries < 500:
            tries += 1
            x, y, rx, ry = blobs[rng.randrange(len(blobs))]
            px, py = x + rng.uniform(-rx, rx) * 0.8, y + rng.uniform(-ry, ry) * 0.8
            if 0 <= int(py) < c.h and 0 <= int(px) < c.w and c.p[int(py)][int(px)] is not None:
                c.dot(px, py, rgb(spots[rng.randrange(len(spots))]))
                placed += 1


def broadleaf(w, h, trunk, blobs, seasons, bark=BARK, name=None, trunk_w=4, birch=False):
    """Four frames of a leafy tree. `seasons` gives (leaf colour, spots,
    count) for spring, summer and fall; winter is bare."""
    frames = []
    cx = (w - 1) / 2
    for season in range(4):
        rng = random.Random(name + str(season))
        c = Canvas(w, h)
        if season == 3:
            bare_branches(c, cx, h - 2, blobs[0][1] - blobs[0][3], max(r[2] for r in blobs) * 0.9, bark, True)
            c.rect(cx - trunk_w / 2 + 0.5, trunk, trunk_w, h - trunk - 1, bark)
            if birch:
                for y in range(trunk + 2, h - 2, 4):
                    c.dot(cx - 1 + (y % 3), y, DARK)
            # snow drifted at the foot
            c.rect(cx - trunk_w / 2 - 1.5, h - 2, trunk_w + 4, 1, SNOW)
        else:
            # The trunk starts inside the canopy so the leaves sit on it.
            canopy_bottom = max(y + ry for (x, y, rx, ry) in blobs)
            top_of_trunk = min(trunk, canopy_bottom - 5)
            c.rect(cx - trunk_w / 2 + 0.5, top_of_trunk, trunk_w, h - top_of_trunk - 1, bark)
            c.rect(cx - trunk_w / 2 - 0.5, h - 2, trunk_w + 2, 1, bark)  # roots
            leaf, spots, n = seasons[season]
            leafy(c, blobs, rgb(leaf), rng, spots, n)
            if birch:
                for y in range(trunk + 2, h - 2, 4):
                    c.dot(cx - 1 + (y % 3), y, DARK)
        frames.append(c.finish())
    return sheet(frames)


def pine_frames(w, h):
    frames = []
    cx = (w - 1) / 2
    for season in range(4):
        c = Canvas(w, h)
        c.rect(cx - 1.5, h - 12, 4, 11, rgb("#6b4630"))
        green = rgb(["#3a7f62", "#2f6f5a", "#2f6a52", "#2c6250"][season])
        tiers = ((3, 6, 13), (11, 9, 14), (21, 12, 15), (30, 15, 13))
        for top, half, height in tiers:
            c.tri(cx, top, half, height, green)
        if season == 0:  # fresh light tips
            for top, half, height in tiers:
                c.dot(cx - half + 1, top + height - 1, light(green, 0.35))
                c.dot(cx + half - 1, top + height - 1, light(green, 0.35))
        if season == 3:  # snow on each tier
            for top, half, height in tiers:
                for x in range(int(cx - half * 0.7), int(cx + half * 0.7) + 1):
                    y = top + int(height * 0.55 * (abs(x - cx) / max(half, 1)) + 1)
                    c.dot(x, y, SNOW)
                c.dot(cx, top, SNOW)
        frames.append(c.finish())
    return sheet(frames)


def small_frames(w, h, draw):
    return sheet([(lambda c: (draw(c, s), c)[1])(Canvas(w, h)).finish() for s in range(4)])


def bush(c, season):
    leaf = rgb(["#5fae5a", "#4f9e5a", "#b8763a", "#6a8a6a"][season])
    c.ell(7.5, 10, 7, 5, leaf)
    c.ell(5, 7, 3.5, 3, leaf)
    c.ell(10.5, 6.5, 3.5, 3, light(leaf, 0.12))
    spots = {0: ("#ffffff", "#ffd6e6"), 1: ("#e0443a", "#e0443a"), 2: ("#e8a33a", "#8a3a2a")}.get(season)
    if spots:
        for i, (x, y) in enumerate(((4, 10), (9, 9), (11, 12), (6, 6))):
            c.dot(x, y, rgb(spots[i % 2]))
    if season == 3:
        c.ell(7.5, 5.5, 5, 1.8, SNOW, top_only=True)
        c.rect(3, 6, 10, 1, SNOW)


def boulder(c, season):
    c.ell(7.5, 10, 7, 5.4, rgb("#8f8a9a"))
    c.ell(5.5, 8, 3, 2, rgb("#aaa6b8"))
    moss = rgb(["#6cbf5a", "#5aa85a", "#9a9a4a", "#f4f8ff"][season])
    c.rect(8, 6, 5, 2, moss)
    c.rect(3, 12, 4, 1, moss if season != 3 else rgb("#8f8a9a"))
    if season == 3:
        c.rect(4, 5, 8, 2, SNOW)


def stump(c, season):
    wood = rgb("#8a6044")
    c.rect(3, 6, 10, 9, wood)
    c.ell(7.5, 6, 5, 2.2, rgb("#d9b07a"))
    c.dot(7, 6, rgb("#a07a50"))
    c.dot(9, 5, rgb("#a07a50"))
    c.rect(1, 14, 3, 1, wood)
    c.rect(12, 14, 3, 1, wood)
    if season == 3:
        c.ell(7.5, 5.5, 5, 2, SNOW)
    elif season == 2:
        c.dot(4, 9, rgb("#e0603a"))  # a little mushroom
        c.dot(4, 8, rgb("#e0603a"))


def log(c, season):
    wood = rgb("#7f5638")
    c.rect(2, 7, 27, 7, wood)
    c.ell(28, 10.5, 2.4, 3.6, rgb("#d9b07a"))
    c.dot(28, 10, rgb("#a07a50"))
    for x in (6, 13, 20):
        c.rect(x, 9, 3, 1, shade(wood, 0.25))
    c.rect(9, 5, 2, 2, wood)  # a broken branch
    moss = {0: "#6cbf5a", 1: "#5aa85a", 2: "#a0903a"}.get(season)
    if moss:
        c.rect(4, 7, 6, 1, rgb(moss))
        c.rect(16, 7, 4, 1, rgb(moss))
    if season == 3:
        c.rect(2, 6, 26, 2, SNOW)


def fence(c, season):
    wood = rgb("#9a6b45")
    c.rect(0, 6, 16, 2, wood)
    c.rect(0, 10, 16, 2, wood)
    c.rect(1, 3, 3, 12, light(wood, 0.1))
    c.rect(12, 3, 3, 12, light(wood, 0.1))
    if season == 3:
        c.rect(1, 2, 3, 1, SNOW)
        c.rect(12, 2, 3, 1, SNOW)
        c.rect(4, 5, 8, 1, SNOW)


def cliff_piece(season, part):
    """16x40: grassy lip (8 rows) over a 32 row face of rounded rocks."""
    rng = random.Random("cliff%d%d" % (season, part))
    rock = rgb("#9b8462")
    crack = rgb("#5e4a3a")
    face = [[crack] * 16 for _ in range(40)]
    # rounded stones packed in rows, wrapping sideways so pieces join up
    for row, y0 in enumerate(range(6, 40, 8)):
        x0 = -rng.randrange(0, 8)
        while x0 < 16:
            w = rng.randrange(7, 11)
            tone = mix(rock, rgb("#7d6a50"), rng.uniform(0, 0.6))
            for y in range(y0, min(y0 + 8, 40)):
                for x in range(x0, x0 + w):
                    dx, dy = (x - x0 - (w - 1) / 2) / (w / 2), (y - y0 - 3.5) / 4
                    if dx * dx + dy * dy <= 1.0:
                        col = tone
                        if dy < -0.45 or dx < -0.6:
                            col = light(tone, 0.18)
                        elif dy > 0.5 or dx > 0.65:
                            col = shade(tone, 0.2)
                        face[y][x % 16] = col
            x0 += w
    img = Image.new("RGBA", (16, 40), (0, 0, 0, 0))
    for y in range(8, 40):
        for x in range(16):
            col = face[y][x]
            if y >= 36:
                col = shade(col, 0.18)  # the foot, in the cliff's shadow
            img.putpixel((x, y), col + (255,))
    lip = rgb(SEASON_GRASS[season]) if season != 3 else SNOW
    for x in range(16):  # the grass lip hangs over the edge a little, unevenly
        drop = 8 + (1 if math.sin(x * 1.3 + part) > 0.2 else 0) + (1 if x % 6 == 2 else 0)
        for y in range(0, drop):
            img.putpixel((x, y), lip + (255,))
        img.putpixel((x, drop), shade(lip, 0.25) + (255,))
    if season != 3:  # tufts and the odd hanging vine
        for _ in range(3):
            x = rng.randrange(1, 15)
            img.putpixel((x, rng.randrange(1, 6)), shade(lip, 0.15) + (255,))
        x = rng.randrange(2, 14)
        for y in range(9, 9 + rng.randrange(2, 6)):
            img.putpixel((x, y), shade(rgb(SEASON_GRASS[season]), 0.25) + (255,))
    if part in (2, 3):  # an end: the cliff's side curves away
        for y in range(40):
            for k in range(0, max(0, 7 - y // 6)):
                x = k if part == 2 else 15 - k
                img.putpixel((x, y), (0, 0, 0, 0))
    return img


CANOPY = [("#3f8f4f", "#2f7342", "#5aa860", "#f4a6c8"), ("#2f7a45", "#255f38", "#3f8f52", None),
          ("#b8662f", "#8f4a2a", "#d98a2b", "#e8c040"), ("#3a5a52", "#2f4a44", "#e8eef4", None)]


CANOPY_SIZE = 128


def canopy_tile(season):
    """A 128x128 tile of tree tops seen from above, crowns of many sizes and
    shades so the repeat isn't noticed; wraps on all sides."""
    rng = random.Random("canopy%d" % season)
    base, dark, lit, spot = (rgb(x) if x else None for x in CANOPY[season])
    n = CANOPY_SIZE
    img = Image.new("RGBA", (n, n), shade(dark, 0.3) + (255,))
    crowns = []
    for _ in range(150):
        r = rng.choice((4.5, 5.5, 6.5, 7.5, 9.0, 11.0))
        tone = rng.choice((base, base, mix(base, dark, 0.4), mix(base, lit, 0.25), mix(base, rgb("#3a6a40"), 0.3)))
        crowns.append((rng.randrange(n), rng.randrange(n), r, tone))
    crowns.sort(key=lambda k: k[1])
    for cx, cy, r, tone in crowns:
        ir = int(r) + 1
        for y in range(-ir, ir + 1):
            for x in range(-ir, ir + 1):
                d = (x * x + y * y) ** 0.5
                wobble = r + math.sin(math.atan2(y, x) * 5 + cx) * 0.8  # lumpy outline
                if d > wobble:
                    continue
                col = tone
                if d > wobble - 1.4 and y > -1:
                    col = shade(tone, 0.28)
                elif ((x + r * 0.35) ** 2 + (y + r * 0.4) ** 2) ** 0.5 < r * 0.3:
                    col = light(tone, 0.07) if season != 3 else SNOW
                img.putpixel(((cx + x) % n, (cy + y) % n), col + (255,))
    for _ in range(n * 3):  # leaf texture
        x, y = rng.randrange(n), rng.randrange(n)
        r, g, b, a = img.getpixel((x, y))
        img.putpixel((x, y), (shade((r, g, b), 0.16) if rng.random() < 0.5 else light((r, g, b), 0.12)) + (255,))
    if spot:
        for _ in range(n // 2):
            img.putpixel((rng.randrange(n), rng.randrange(n)), spot + (255,))
    return img


EDGE_VARIANTS = 6


def canopy_edge(season, variant):
    """48x44 leafy crowns that round off the forest's edge; six shapes."""
    rng = random.Random("edge%d-%d" % (season, variant))
    base, dark, lit, spot = (rgb(x) if x else None for x in CANOPY[season])
    tone = [base, mix(base, dark, 0.3), mix(base, lit, 0.2), base, mix(base, rgb("#3a6a40"), 0.25), mix(base, dark, 0.15)][variant]
    c = Canvas(48, 44)
    blobs = []
    for _ in range(rng.randrange(3, 6)):
        rx = rng.uniform(7, 13)
        blobs.append((24 + rng.uniform(-1, 1) * (23 - rx) * 0.6, rng.uniform(16, 28), rx, rx * rng.uniform(0.75, 0.95)))
    blobs.sort(key=lambda b: b[1])
    leafy(c, blobs, tone, rng, (CANOPY[season][3],) if spot else None, 6)
    if season == 3:
        for (x, y, rx, ry) in blobs:
            c.ell(x - rx * 0.2, y - ry * 0.55, rx * 0.45, 1.5, SNOW)
    return c.finish()


def trail_piece(season, mask):
    """Dirt with soft, slightly wavy edges on the sides that don't join
    another trail piece."""
    rng = random.Random("trail%d%d" % (season, mask))
    dirt = rgb(["#c9a26a", "#c49a62", "#b48a58", "#d8cfc8"][season])
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    up, right, down, left = mask & 1, mask & 2, mask & 4, mask & 8
    wobble = [2 + (1 if math.sin(i * 1.7 + mask) > 0.4 else 0) for i in range(16)]
    for y in range(16):
        for x in range(16):
            if (not up and y < wobble[x]) or (not down and 15 - y < wobble[x]):
                continue
            if (not left and x < wobble[y]) or (not right and 15 - x < wobble[y]):
                continue
            # round the outside corners
            corner = None
            if not up and not left:
                corner = (4.5, 4.5) if x < 5 and y < 5 else None
            if not up and not right and x > 10 and y < 5:
                corner = (10.5, 4.5)
            if not down and not left and x < 5 and y > 10:
                corner = (4.5, 10.5)
            if not down and not right and x > 10 and y > 10:
                corner = (10.5, 10.5)
            if corner and ((x - corner[0]) ** 2 + (y - corner[1]) ** 2) ** 0.5 > 3.2:
                continue
            col = dirt
            if rng.random() < 0.08:
                col = shade(dirt, 0.1)
            elif rng.random() < 0.05:
                col = light(dirt, 0.12)
            img.putpixel((x, y), col + (255,))
    # a darker rim where the dirt meets the grass
    for y in range(16):
        for x in range(16):
            if img.getpixel((x, y))[3] == 0:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < 16 and 0 <= ny < 16 and img.getpixel((nx, ny))[3] == 0:
                    img.putpixel((x, y), shade(dirt, 0.18) + (255,))
                    break
    if rng.random() < 0.6:
        x, y = rng.randrange(5, 11), rng.randrange(5, 11)
        img.putpixel((x, y), rgb("#a09888") + (255,))
    return img


def make_scenery():
    trees = {
        "oak": broadleaf(32, 44, 28, [(15.5, 15, 14, 12), (8, 22, 7, 6), (23, 22, 7, 6)],
                         [("#5fb86a", ("#ffffff", "#ffe0ec"), 9), ("#3f8f52", None, 0), ("#d98a2b", ("#c4572f", "#f0b040"), 16)], name="oak"),
        "maple": broadleaf(32, 48, 32, [(15.5, 14, 11, 10), (7, 21, 7, 7), (24, 21, 7, 7), (15.5, 25, 10, 7)],
                           [("#78c45a", None, 0), ("#4c9a3e", None, 0), ("#d8402e", ("#f06a2a", "#a82a2a"), 18)], name="maple"),
        "birch": broadleaf(24, 46, 22, [(11.5, 14, 8, 11), (6.5, 21, 5, 6), (16.5, 21, 5, 6)],
                           [("#9ad46a", None, 0), ("#6cb04a", None, 0), ("#f0c040", ("#e8a030",), 10)],
                           bark=rgb("#ece6dc"), name="birch", trunk_w=3, birch=True),
        "cherry": broadleaf(32, 44, 29, [(15.5, 15, 14, 10), (7, 20, 7, 6), (24, 20, 7, 6)],
                            [("#f4a6c8", ("#ffffff", "#e87aa8"), 14), ("#4f9e5a", None, 0), ("#e08a3a", ("#c4572f",), 10)],
                            bark=rgb("#6e4a3a"), name="cherry"),
        "apple": broadleaf(32, 44, 28, [(15.5, 16, 13, 11), (8, 22, 6, 5), (23, 22, 6, 5)],
                           [("#6cbf5a", ("#ffffff",), 10), ("#4a9a48", ("#e0443a",), 8), ("#b0a03a", ("#e0443a", "#d9822b"), 10)], name="apple"),
        "pine": pine_frames(32, 48),
    }
    for kind, img in trees.items():
        save(img, "scenery", kind + ".png")
    for kind, (w, draw) in {"bush": (16, bush), "boulder": (16, boulder), "stump": (16, stump), "log": (32, log), "fence": (16, fence)}.items():
        save(small_frames(w, 16, draw), "scenery", kind + ".png")
    cliff = Image.new("RGBA", (64, 160), (0, 0, 0, 0))
    for season in range(4):
        for part in range(4):
            cliff.paste(cliff_piece(season, part), (part * 16, season * 40))
    save(cliff, "scenery", "cliff.png")
    for season in range(4):
        save(canopy_tile(season), "scenery", "canopy_%d.png" % season)
    edges = Image.new("RGBA", (48 * EDGE_VARIANTS, 44 * 4), (0, 0, 0, 0))
    for season in range(4):
        for variant in range(EDGE_VARIANTS):
            edges.paste(canopy_edge(season, variant), (variant * 48, season * 44))
    save(edges, "scenery", "canopy_edge.png")
    trail = Image.new("RGBA", (256, 64), (0, 0, 0, 0))
    for season in range(4):
        for mask in range(16):
            trail.paste(trail_piece(season, mask), (mask * 16, season * 16))
    save(trail, "scenery", "trail.png")

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
    make_farmyard()
    make_items()
    make_tree()
    make_scenery()
    print("sprites written to", os.path.normpath(OUT))
