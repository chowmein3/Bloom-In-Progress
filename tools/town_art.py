"""The town's art, called from make_art.py (make_town()).

assets/sprites/town_<season>.png: the town's ground, one picture per season,
  16 pixels a tile, painted from TOWN_MAP in scripts/game_state.gd (read from
  there, so the map has one home): grass, paths with soft edges, the river
  with sandy banks, the cobbled plaza, the cliff and its stairs, bridges, the
  waterfall, the flower meadow and the orchard.
assets/sprites/town_<building>.png: each building in TOWN_BUILDINGS, as wide
  as its footprint (plus a little eave), base on the bottom row.
assets/sprites/town_props.png: a 32x32 frame per prop (TownView.PROPS order),
  base on the bottom row, centred on the prop's footprint.
assets/sprites/villager_<id>.png: the townsfolk, 16x24 like the villagers;
  keeper_town.png is Bristle standing in town.
"""
import math
import os
import random
import re

import numpy as np
from PIL import Image, ImageFilter

from make_art import (Canvas, DARK, OUTLINE, SEASON_DECO, SEASON_GRASS, WHITE, grass_tile, light, mix, rgb, save,
                      shade, sheet)

TILE = 16
GAME_STATE = os.path.join(os.path.dirname(__file__), "..", "scripts", "game_state.gd")


def read_town():
    """TOWN_MAP and TOWN_BUILDINGS from game_state.gd."""
    text = open(GAME_STATE).read()
    block = re.search(r"const TOWN_MAP: Array\[String\] = \[(.*?)\]", text, re.S).group(1)
    rows = re.findall(r'"([^"]*)"', block)
    builds = {}
    block = re.search(r"const TOWN_BUILDINGS: Dictionary = \{(.*?)\}", text, re.S).group(1)
    for name, x, y, w, h in re.findall(r'"(\w+)": Rect2i\((\d+), (\d+), (\d+), (\d+)\)', block):
        builds[name] = (int(x), int(y), int(w), int(h))
    return rows, builds


# ------------------------------------------------------------------ ground

WATER = ["#5aa6dc", "#4f9fd8", "#4f8fc0", "#a9d4ea"]
DEEP = ["#3f82c0", "#3a7fc0", "#3a6f9f", "#8fc0dc"]
SAND = ["#e9d29c", "#e6cc92", "#d9bd86", "#e9e6df"]
DIRT = ["#c9a26a", "#c49a62", "#b48a58", "#d8cfc8"]
COBBLE = ["#cbbfa9", "#c9bda6", "#bfb19a", "#dcd8d2"]
ROCK = rgb("#8f8070")


def smooth(mask, upscale=TILE, cut=0.5):
    """A tile mask (H x W of 0/1) made into a pixel mask with rounded edges."""
    h, w = mask.shape
    pad = np.pad(mask.astype(np.float32), 2, mode="edge")
    img = Image.fromarray((pad * 255).astype(np.uint8)).resize(((w + 4) * upscale, (h + 4) * upscale), Image.BILINEAR)
    img = img.filter(ImageFilter.GaussianBlur(upscale * 0.45))  # rounder, more natural bends
    big = np.asarray(img).astype(np.float32) / 255.0
    big = big[2 * upscale:(h + 2) * upscale, 2 * upscale:(w + 2) * upscale]
    return big > cut


def grow(mask, r):
    out = mask.copy()
    for dy in range(-r, r + 1):
        for dx in range(-r, r + 1):
            if dx * dx + dy * dy <= r * r:
                out |= np.roll(np.roll(mask, dy, 0), dx, 1)
    return out


def town_ground(rows, season):
    h, w = len(rows), len(rows[0])
    W, H = w * TILE, h * TILE
    rng = random.Random("town%d" % season)
    grass = rgb(SEASON_GRASS[season])
    deco = rgb(SEASON_DECO[season])
    img = Image.new("RGBA", (W, H), (0, 0, 0, 255))
    # Grass everywhere first, tile by tile, in a few looks.
    looks = [grass_tile(grass, rng), grass_tile(shade(grass, 0.04), rng), grass_tile(grass, rng, tufts=2), grass_tile(grass, rng, tufts=1, deco=deco)]
    woods = [grass_tile(shade(grass, 0.22), rng), grass_tile(shade(grass, 0.26), rng, tufts=2)]
    high = [grass_tile(light(grass, 0.07), rng), grass_tile(light(grass, 0.05), rng, tufts=2), grass_tile(light(grass, 0.07), rng, tufts=1, deco=deco)]
    for y in range(h):
        for x in range(w):
            ch = rows[y][x]
            if ch == "T":
                tile = woods[(x * 3 + y * 5) % 2]
            elif ch in "u^":
                tile = high[(x * 5 + y * 3) % 3]
            else:
                tile = looks[[0, 1, 0, 2, 1, 0, 3, 1][(x * 7 + y * 13) % 8]]
            img.paste(tile, (x * TILE, y * TILE))
    px = np.array(img).astype(np.int32)

    def tiles(chars):
        return np.array([[1 if rows[y][x] in chars else 0 for x in range(w)] for y in range(h)])

    noise = np.random.default_rng(season + 5).random((H, W))

    def paint(mask, colour, jitter=0.06, dark_edge=None):
        c = np.array(colour, dtype=np.float32)
        shades = 1.0 + (noise - 0.5) * jitter * 2
        for k in range(3):
            px[..., k] = np.where(mask, np.clip(c[k] * shades, 0, 255), px[..., k])
        if dark_edge is not None:
            edge = mask & ~(np.roll(mask, 1, 0) & np.roll(mask, -1, 0) & np.roll(mask, 1, 1) & np.roll(mask, -1, 1))
            for k in range(3):
                px[..., k] = np.where(edge, dark_edge[k], px[..., k])

    # The orchard's grass is kept short: mown stripes.
    orchard = np.kron(tiles("o"), np.ones((TILE, TILE), dtype=bool)).astype(bool)
    stripes = (np.arange(H)[:, None] // 6 % 2 == 0) & orchard
    for k in range(3):
        px[..., k] = np.where(stripes, np.clip(px[..., k] * 1.05, 0, 255), px[..., k])
    # The flower meadow: flowers everywhere (snowdrops in winter).
    meadow = tiles("*")
    petals = [rgb("#ff9fc2"), rgb("#fff3a0"), rgb("#ffffff"), rgb("#b9a0ff"), deco]
    if season == 3:
        petals = [rgb("#ffffff"), rgb("#d9ecff")]
    for y in range(h):
        for x in range(w):
            if meadow[y, x]:
                for _ in range(7):
                    fx, fy = x * TILE + rng.randrange(1, 15), y * TILE + rng.randrange(1, 15)
                    col = rng.choice(petals)
                    for dx, dy in ((0, 0), (1, 0), (-1, 0), (0, -1), (0, 1)):
                        if (dx, dy) == (0, 0):
                            px[fy, fx, :3] = rgb("#ffd24a") if season != 3 else (255, 255, 255)
                        elif rng.random() < 0.85:
                            px[fy + dy, fx + dx, :3] = col
                    px[fy + 2, fx, :3] = shade(grass, 0.3)
    # The river, with a sandy bank. Bridges stand over water, the dock half.
    water_tiles = tiles("~w")
    for y in range(h):
        for x in range(w):
            if rows[y][x] == "=":
                up = y
                while up > 0 and rows[up][x] == "=":
                    up -= 1
                down = y
                while down < h - 1 and rows[down][x] == "=":
                    down += 1
                if rows[up][x] in "~w" or rows[down][x] in "~w":
                    water_tiles[y, x] = 1
    water = smooth(water_tiles)
    bank = grow(water, 4) & ~water
    paint(bank, rgb(SAND[season]), 0.05)
    paint(water, rgb(WATER[season]), 0.03)
    deep = smooth(water_tiles, cut=0.82)
    paint(deep, rgb(DEEP[season]), 0.03)
    lip = water & ~grow(~water, 1)  # a pale rim where water meets sand
    for k in range(3):
        px[..., k] = np.where(water & ~lip, px[..., k], np.where(water, np.clip(px[..., k] + 28, 0, 255), px[..., k]))
    # Paths, soft-edged dirt (a darker rim), and the cobbled plaza.
    path = smooth(tiles(",s"), cut=0.45) & ~water
    paint(path, rgb(DIRT[season]), 0.07)
    rim = grow(path, 1) & ~path & ~water & ~bank
    for k in range(3):
        px[..., k] = np.where(rim, np.clip(px[..., k] * 0.86, 0, 255), px[..., k])
    for y in range(h):
        for x in range(w):
            if rows[y][x] == ",":
                for _ in range(2):  # pebbles
                    sx, sy = x * TILE + rng.randrange(2, 14), y * TILE + rng.randrange(2, 14)
                    if path[sy, sx]:
                        px[sy, sx, :3] = shade(rgb(DIRT[season]), 0.25)
    cobble = tiles("#")
    stone = rgb(COBBLE[season])
    for y in range(h):
        for x in range(w):
            if not cobble[y, x]:
                continue
            x0, y0 = x * TILE, y * TILE
            px[y0:y0 + TILE, x0:x0 + TILE, :3] = shade(stone, 0.32)  # mortar
            for by in range(0, TILE, 5):  # stones in staggered rows
                off = 3 if (y * 3 + by // 5) % 2 else 0
                for bx in range(-off, TILE, 6):
                    tone = mix(stone, shade(stone, 0.12), rng.random())
                    for sy in range(by + 1, min(by + 5, TILE)):
                        for sx in range(max(bx + 1, 0), min(bx + 6, TILE)):
                            px[y0 + sy, x0 + sx, :3] = tone
                    if bx + 1 >= 0 and by + 1 < TILE:
                        px[y0 + by + 1, x0 + max(bx + 1, 0), :3] = light(tone, 0.25)
            if season == 3:
                for _ in range(10):
                    px[y0 + rng.randrange(TILE), x0 + rng.randrange(TILE), :3] = (255, 255, 255)
    plaza = np.kron(cobble, np.ones((TILE, TILE), dtype=bool)).astype(bool)
    border = grow(plaza, 2) & ~plaza & ~water
    for k in range(3):
        px[..., k] = np.where(border, shade(stone, 0.45)[k], px[..., k])
    # The cliff: a rock face two tiles tall below the high ground, a side
    # face down its east edge, and a grass lip hanging over the top.
    for y in range(h):
        for x in range(w):
            if rows[y][x] != "^":
                continue
            x0, y0 = x * TILE, y * TILE
            side = x + 1 < w and rows[y][x + 1] not in "^u" and (y + 1 < h and rows[y + 1][x] == "^")
            for sy in range(TILE):
                for sx in range(TILE):
                    gy, gx = y0 + sy, x0 + sx
                    band = (gy // 7 + (gx // 9) % 2) % 3
                    tone = mix(ROCK, rgb("#a39380"), 0.5 * band / 2 + 0.25 * math.sin(gx * 0.7 + gy * 0.3))
                    if (gx + gy * 2) % 9 == 0:
                        tone = shade(tone, 0.25)
                    if season == 3 and rng.random() < 0.05:
                        tone = (240, 244, 248)
                    px[gy, gx, :3] = tone
            above = rows[y - 1][x] if y > 0 else "T"
            if above in "u":  # the grass lip
                lip_c = light(grass, 0.07)
                for sx in range(TILE):
                    drop = 3 + (1 if math.sin((x0 + sx) * 1.3) > 0.2 else 0)
                    for sy in range(drop):
                        px[y0 + sy, x0 + sx, :3] = lip_c
                    px[y0 + drop, x0 + sx, :3] = shade(lip_c, 0.3)
            below = rows[y + 1][x] if y + 1 < h else "T"
            if below not in "^s":  # the cliff's foot, in shadow
                px[y0 + TILE - 3:y0 + TILE, x0:x0 + TILE, :3] = (px[y0 + TILE - 3:y0 + TILE, x0:x0 + TILE, :3] * 0.75).astype(np.int32)
                for sy in range(3):  # and a shadow on the grass beneath
                    if y0 + TILE + sy < H:
                        px[y0 + TILE + sy, x0:x0 + TILE, :3] = (px[y0 + TILE + sy, x0:x0 + TILE, :3] * (0.7 + sy * 0.08)).astype(np.int32)
            if side:
                pass
    # Stairs: stone steps cut down the cliff.
    for y in range(h):
        for x in range(w):
            if rows[y][x] != "s":
                continue
            x0, y0 = x * TILE, y * TILE
            for sy in range(TILE):
                for sx in range(TILE):
                    step = sy % 5
                    tone = rgb("#c8bba8") if step < 3 else shade(rgb("#c8bba8"), 0.3 if step == 4 else 0.15)
                    px[y0 + sy, x0 + sx, :3] = tone
            edge = 0 if x == 0 or rows[y][x - 1] != "s" else (TILE - 1 if x + 1 >= w or rows[y][x + 1] != "s" else -1)
            if x > 0 and rows[y][x - 1] != "s":
                px[y0:y0 + TILE, x0:x0 + 2, :3] = shade(ROCK, 0.2)
            if x + 1 < w and rows[y][x + 1] != "s":
                px[y0:y0 + TILE, x0 + TILE - 2:x0 + TILE, :3] = shade(ROCK, 0.2)
    # Bridges: planks across, with a rail along each side.
    wood = rgb("#a8744a") if season != 3 else rgb("#b9906a")
    for y in range(h):
        for x in range(w):
            if rows[y][x] != "=":
                continue
            x0, y0 = x * TILE, y * TILE
            for sy in range(TILE):
                for sx in range(TILE):
                    plank = (x0 + sx) // 4
                    tone = mix(wood, shade(wood, 0.15), (plank * 37 % 5) / 5)
                    if (x0 + sx) % 4 == 3:
                        tone = shade(wood, 0.35)
                    px[y0 + sy, x0 + sx, :3] = tone
            if y == 0 or rows[y - 1][x] != "=":
                px[y0:y0 + 2, x0:x0 + TILE, :3] = shade(wood, 0.45)
            if y + 1 >= h or rows[y + 1][x] != "=":
                px[y0 + TILE - 2:y0 + TILE, x0:x0 + TILE, :3] = shade(wood, 0.45)
                px[y0 + TILE:y0 + TILE + 2, x0:x0 + TILE, :3] = (px[y0 + TILE:y0 + TILE + 2, x0:x0 + TILE, :3] * 0.75).astype(np.int32)
    # The waterfall: white water falling over dark rock.
    for y in range(h):
        for x in range(w):
            if rows[y][x] != "w":
                continue
            x0, y0 = x * TILE, y * TILE
            for sy in range(TILE):
                for sx in range(TILE):
                    streak = ((x0 + sx) * 7) % 5
                    tone = mix(rgb(WATER[season]), (255, 255, 255), 0.35 + 0.13 * streak)
                    px[y0 + sy, x0 + sx, :3] = tone
            if x > 0 and rows[y][x - 1] != "w":
                px[y0:y0 + TILE, x0 - 3:x0, :3] = shade(ROCK, 0.2)
            if x + 1 < w and rows[y][x + 1] != "w":
                px[y0:y0 + TILE, x0 + TILE:x0 + TILE + 3, :3] = shade(ROCK, 0.2)
    return Image.fromarray(np.clip(px, 0, 255).astype(np.uint8), "RGBA")


def make_town():
    rows, builds = read_town()
    for season in range(4):
        save(town_ground(rows, season), "town_%d.png" % season)
    make_buildings(builds)
    make_props()
    make_folk()
    make_rooms_art()


# --------------------------------------------------------------- buildings

def roof_gable(c, x0, x1, top, base, colour, ridge=None):
    """A pitched roof between x0 and x1 (exclusive) from `top` down to `base`,
    shingled in rows."""
    mid = (x0 + x1 - 1) / 2
    half = (x1 - x0) / 2
    height = base - top
    for j in range(height):
        r = half * (j + 1) / height
        for x in range(x0, x1):
            if abs(x - mid) <= r + 0.5:
                tone = colour if (j // 3) % 2 == 0 else shade(colour, 0.12)
                c.px(x, top + j, tone)
    if ridge:
        c.rect(int(mid), top, 1, 2, ridge)


def roof_hip(c, x0, x1, top, base, colour, inset=6):
    """A wide roof with sloped ends: flat top, angled sides."""
    height = base - top
    for j in range(height):
        pad = int(inset * (height - 1 - j) / max(height - 1, 1))
        tone = colour if (j // 3) % 2 == 0 else shade(colour, 0.12)
        c.rect(x0 + pad, top + j, x1 - x0 - pad * 2, 1, tone)


def windows(c, xs, y, w=6, h=6, frame=None, glass="#bfe6ff", lit=False):
    for x in xs:
        if frame:
            c.rect(x - 1, y - 1, w + 2, h + 2, frame)
        c.rect(x, y, w, h, rgb("#ffe7a0") if lit else rgb(glass))
        c.rect(x + w // 2, y, 1, h, shade(rgb(glass), 0.4))
        c.rect(x, y + h // 2, w, 1, shade(rgb(glass), 0.4))


def door(c, x, y, w, h, colour, arch=False, knob="#ffd24a"):
    c.rect(x, y, w, h, colour)
    if arch:
        c.ell(x + (w - 1) / 2, y, w / 2, 3, colour, top_only=True)
    c.rect(x + w // 2, y, 1, h, shade(colour, 0.3))
    c.dot(x + w - 2, y + h // 2, rgb(knob))


def sign(c, x, y, w, h, board, draw):
    c.rect(x, y, w, h, board)
    for i, dx in enumerate((x + 1, x + w - 2)):
        c.dot(dx, y - 1, rgb("#5a4030"))
    draw(c)


def make_buildings(builds):
    for name, (bx, by, bw, bh) in builds.items():
        w = bw * TILE + 8
        img = BUILDERS[name](w)
        save(img, "town_%s.png" % name)


def b_store(w):  # Bristle's general store: teal shopfront, striped awning, crates
    h = 80
    c = Canvas(w, h)
    wall, trim = rgb("#e9d7b4"), rgb("#2f8f86")
    roof_gable(c, 2, w - 2, 10, 38, rgb("#c9644a"), ridge=rgb("#8a4030"))
    c.rect(6, 36, w - 12, 42, wall)
    c.rect(6, 36, w - 12, 2, shade(wall, 0.2))
    for x in range(6, w - 6, 6):  # awning
        c.rect(x, 44, 3, 6, trim)
        c.rect(x + 3, 44, 3, 6, WHITE)
    c.rect(6, 50, w - 12, 1, shade(trim, 0.3))
    windows(c, [10, w - 26], 54, w=14, h=10, frame=trim)
    for x in (12, w - 24):  # goods in the windows
        c.dot(x + 2, 61, rgb("#e0605a"))
        c.dot(x + 5, 61, rgb("#ffd24a"))
        c.dot(x + 8, 61, rgb("#5aa85a"))
    door(c, w // 2 - 5, 56, 10, 22, trim)
    sign(c, w // 2 - 12, 24, 24, 8, rgb("#fbeed3"), lambda c: (c.dot(w // 2 - 6, 28, rgb("#8a5e3a")), c.dot(w // 2 - 3, 27, rgb("#8a5e3a")), c.dot(w // 2, 28, rgb("#8a5e3a")), c.dot(w // 2 + 3, 27, rgb("#8a5e3a")), c.dot(w // 2 + 6, 28, rgb("#8a5e3a"))))
    return c.finish()


def b_bakery(w):  # Juniper's bakery: cream and pink, a chimney, a loaf sign
    h = 82
    c = Canvas(w, h)
    wall = rgb("#fbe3d0")
    c.rect(w - 22, 6, 7, 18, rgb("#b9897a"))  # chimney
    c.rect(w - 23, 5, 9, 2, rgb("#8f6558"))
    roof_gable(c, 2, w - 2, 12, 40, rgb("#8a5e3a"))
    c.rect(6, 38, w - 12, 42, wall)
    for x in range(6, w - 6, 6):
        c.rect(x, 46, 3, 5, rgb("#ff8fb3"))
        c.rect(x + 3, 46, 3, 5, WHITE)
    windows(c, [10, w - 24], 55, w=12, h=9, frame=rgb("#c9644a"))
    for x in (12, w - 22):  # bread in the window
        c.ell(x + 4, 61, 3, 1.6, rgb("#d9a25a"))
    door(c, w // 2 - 5, 57, 10, 23, rgb("#c9644a"), arch=True)
    c.ell(w / 2, 28, 7, 4, rgb("#fbeed3"))
    c.ell(w / 2, 28, 5, 2.4, rgb("#d9a25a"))  # a loaf
    c.rect(w // 2 - 3, 27, 1, 2, shade(rgb("#d9a25a"), 0.3))
    c.rect(w // 2 + 1, 27, 1, 2, shade(rgb("#d9a25a"), 0.3))
    return c.finish()


def b_forge(w):  # Flint's forge: stone, a dark roof, a glowing furnace
    h = 80
    c = Canvas(w, h)
    stone = rgb("#9a9488")
    c.rect(w - 20, 2, 9, 24, shade(stone, 0.1))  # chimney
    c.rect(w - 21, 1, 11, 3, shade(stone, 0.3))
    roof_gable(c, 2, w - 2, 14, 40, rgb("#4f5466"))
    c.rect(6, 38, w - 12, 40, stone)
    for y in range(41, 78, 5):
        for x in range(6 + (3 if (y // 5) % 2 else 0), w - 6, 7):
            c.rect(x, y, 1, 4, shade(stone, 0.25))
        c.rect(6, y, w - 12, 1, shade(stone, 0.25))
    c.rect(10, 52, 18, 16, rgb("#2a2024"))  # the furnace mouth
    c.ell(18.5, 52, 9, 4, rgb("#2a2024"), top_only=True)
    c.rect(12, 58, 14, 10, rgb("#f08a2e"))
    c.rect(14, 62, 10, 6, rgb("#ffd24a"))
    door(c, w - 28, 56, 12, 22, rgb("#6b4630"))
    c.rect(w // 2 - 6, 26, 12, 8, rgb("#4f4a4a"))  # an anvil on the sign
    c.rect(w // 2 - 4, 27, 8, 2, rgb("#c9c2b5"))
    c.rect(w // 2 - 1, 29, 2, 3, rgb("#c9c2b5"))
    return c.finish()


def b_carpenter(w):  # Birch & Bough: log walls, green roof, big doors, a saw
    h = 80
    c = Canvas(w, h)
    log = rgb("#b07a4a")
    roof_gable(c, 0, w, 10, 40, rgb("#4f9e5a"))
    c.rect(5, 38, w - 10, 40, log)
    for y in range(40, 78, 4):
        c.rect(5, y, w - 10, 1, shade(log, 0.25))
    for x in (5, w - 7):
        for y in range(40, 78, 4):
            c.ell(x + 1, y + 1.5, 2, 1.6, light(log, 0.15))
    c.rect(w // 2 - 11, 52, 22, 26, rgb("#6b4630"))  # barn doors
    c.rect(w // 2, 52, 1, 26, shade(rgb("#6b4630"), 0.3))
    for d in range(10):
        c.dot(w // 2 - 10 + d, 53 + int(d * 2.4), shade(rgb("#6b4630"), 0.35))
        c.dot(w // 2 + 1 + d, 76 - int(d * 2.4), shade(rgb("#6b4630"), 0.35))
    windows(c, [9, w - 19], 48, w=10, h=8, frame=shade(log, 0.35))
    c.rect(w // 2 - 9, 26, 18, 6, rgb("#c9c2b5"))  # a saw blade on the gable
    for x in range(w // 2 - 9, w // 2 + 9, 2):
        c.dot(x, 32, rgb("#8f8a80"))
    c.rect(w // 2 + 8, 25, 4, 8, rgb("#8a5e3a"))
    return c.finish()


def b_inn(w):  # The Snug Mug: two storeys of timber frame, warm windows, a mug sign
    h = 96
    c = Canvas(w, h)
    wall, beam = rgb("#f6e6c8"), rgb("#7a5234")
    c.rect(12, 4, 7, 18, rgb("#b9897a"))
    c.rect(11, 3, 9, 2, rgb("#8f6558"))
    roof_gable(c, 0, w, 8, 40, rgb("#d9804a"))
    c.rect(4, 38, w - 8, 56, wall)
    for x in range(4, w - 4, 14):
        c.rect(x, 38, 2, 56, beam)
    c.rect(4, 38, w - 8, 2, beam)
    c.rect(4, 62, w - 8, 2, beam)
    c.rect(w - 6, 38, 2, 56, beam)
    windows(c, [10, 38, w - 22], 44, w=10, h=10, frame=beam, lit=True)
    windows(c, [10, w - 22], 68, w=10, h=10, frame=beam, lit=True)
    door(c, w // 2 - 6, 70, 12, 24, rgb("#8a3f2e"), arch=True)
    c.rect(w // 2 + 9, 66, 9, 8, rgb("#fbeed3"))  # the hanging mug
    c.rect(w // 2 + 11, 68, 4, 5, rgb("#d9a25a"))
    c.rect(w // 2 + 15, 69, 1, 3, rgb("#d9a25a"))
    c.rect(w // 2 + 11, 67, 4, 1, WHITE)
    return c.finish()


def b_townhall(w):  # Town hall: red brick, white trim, a clock tower and a flag
    h = 104
    c = Canvas(w, h)
    brick, trim = rgb("#c0634a"), rgb("#fbeed3")
    mid = w // 2
    c.rect(mid - 9, 12, 18, 40, brick)  # the tower
    roof_gable(c, mid - 11, mid + 11, 0, 14, rgb("#4f5466"))
    c.ell(mid - 0.5, 24, 6, 6, trim)
    c.ell(mid - 0.5, 24, 4.5, 4.5, rgb("#fffaf0"))
    c.rect(mid, 20, 1, 5, DARK)
    c.rect(mid, 24, 3, 1, DARK)
    c.rect(mid + 8, 0, 1, 8, rgb("#6b5a4a"))  # flag
    c.rect(mid + 9, 0, 6, 4, rgb("#e0605a"))
    roof_hip(c, 0, w, 40, 58, rgb("#4f5466"), inset=10)
    c.rect(4, 56, w - 8, 46, brick)
    for y in range(59, 100, 4):
        for x in range(4 + (2 if (y // 4) % 2 else 0), w - 4, 6):
            c.rect(x, y, 1, 3, shade(brick, 0.2))
    c.rect(4, 56, w - 8, 3, trim)
    for x in range(8, w - 8, 18):  # columns
        c.rect(x, 62, 4, 40, trim)
    windows(c, [16, 34, w - 40, w - 22], 66, w=8, h=12, frame=trim)
    c.rect(mid - 12, 96, 24, 6, rgb("#c8bba8"))  # steps
    door(c, mid - 6, 76, 12, 20, rgb("#5a3a52"), arch=True)
    return c.finish()


def b_museum(w):  # Valley Museum: pale stone, a pediment and columns, a dome
    h = 96
    c = Canvas(w, h)
    stone, roof = rgb("#e6e0d2"), rgb("#3f8f86")
    mid = w // 2
    c.ell(mid - 0.5, 20, 12, 12, roof, top_only=True)  # the dome
    c.rect(mid - 12, 18, 24, 6, roof)
    c.rect(mid, 4, 1, 5, rgb("#ffd24a"))
    c.tri(mid - 0.5, 24, w / 2 - 1, 16, stone)  # pediment
    c.ell(mid - 0.5, 34, 4, 3, roof)
    c.rect(2, 40, w - 4, 4, shade(stone, 0.1))
    c.rect(6, 44, w - 12, 50, stone)
    for x in range(10, w - 10, 13):
        c.rect(x, 46, 6, 44, light(stone, 0.4))
        c.rect(x + 4, 46, 2, 44, shade(stone, 0.12))
    c.rect(2, 88, w - 4, 6, shade(stone, 0.15))  # steps
    c.rect(4, 86, w - 8, 2, light(stone, 0.2))
    door(c, mid - 6, 66, 12, 20, rgb("#5a3a52"), arch=True)
    return c.finish()


def b_apothecary(w):  # Sage's apothecary: green boards, plum roof, herbs, a round window
    h = 84
    c = Canvas(w, h)
    wall = rgb("#9cc99a")
    roof_gable(c, 0, w, 14, 42, rgb("#8a4f8f"))
    c.rect(5, 40, w - 10, 42, wall)
    for x in range(5, w - 5, 4):
        c.rect(x, 40, 1, 42, shade(wall, 0.15))
    c.ell(w / 2 - 0.5, 30, 5, 5, rgb("#fbeed3"))
    c.ell(w / 2 - 0.5, 30, 3.5, 3.5, rgb("#bfe6ff"))
    windows(c, [8], 52, w=10, h=10, frame=rgb("#6b4630"))
    door(c, w - 22, 58, 11, 22, rgb("#6b4630"), arch=True)
    for i, x in enumerate(range(8, w - 8, 5)):  # herbs drying under the eaves
        c.rect(x, 43, 1, 4, rgb("#6b4630"))
        c.ell(x, 48, 1.6, 2, rgb(["#5aa85a", "#b9a0ff", "#e0b04a"][i % 3]))
    c.rect(10, 66, 8, 6, rgb("#c9744a"))  # a pot of herbs
    c.ell(14, 64, 4, 3, rgb("#5aa85a"))
    return c.finish()


def b_fishshack(w):  # The Wet Line: weathered blue planks on stilts, nets, a fish sign
    h = 76
    c = Canvas(w, h)
    plank = rgb("#6f9fb8")
    roof_gable(c, 0, w, 12, 36, rgb("#5f6670"))
    c.rect(4, 34, w - 8, 34, plank)
    for x in range(4, w - 4, 4):
        c.rect(x, 34, 1, 34, shade(plank, 0.2))
    for x in (6, w - 9):  # stilts
        c.rect(x, 68, 3, 8, rgb("#6b4630"))
    c.rect(4, 66, w - 8, 3, rgb("#8a6238"))
    windows(c, [8], 42, w=10, h=8, frame=rgb("#fbeed3"))
    door(c, w - 20, 46, 10, 20, rgb("#8a6238"))
    for i in range(6):  # a net hung on the wall
        c.dot(9 + i * 2, 54 + (i % 2), rgb("#e9e4dc"))
        c.dot(9 + i * 2, 58 - (i % 2), rgb("#e9e4dc"))
    c.ell(w / 2 - 0.5, 26, 8, 3, rgb("#f2b84a"))  # the fish sign
    c.tri(w / 2 + 9, 23, 2.5, 6, rgb("#e0803a"))
    c.dot(int(w / 2 - 5), 25, DARK)
    return c.finish()


def b_home(colours):
    wall_c, roof_c, door_c, extra = colours

    def build(w):
        h = 76
        c = Canvas(w, h)
        wall = rgb(wall_c)
        if extra == "chimney":
            c.rect(w - 18, 8, 6, 16, rgb("#9a9488"))
        roof_gable(c, 0, w, 12, 42, rgb(roof_c))
        if extra == "moss":
            for x in range(6, w - 6, 5):
                c.dot(x, 30 + (x % 3), rgb("#6fae5a"))
                c.dot(x + 2, 36 - (x % 2), rgb("#6fae5a"))
        c.rect(5, 40, w - 10, 34, wall)
        if extra == "stone" or extra == "moss":
            for y in range(43, 74, 5):
                for x in range(5 + (3 if (y // 5) % 2 else 0), w - 5, 7):
                    c.rect(x, y, 1, 4, shade(wall, 0.2))
                c.rect(5, y, w - 10, 1, shade(wall, 0.2))
        windows(c, [9, w - 19], 48, w=10, h=8, frame=shade(wall, 0.35))
        door(c, w // 2 - 5, 54, 10, 20, rgb(door_c), arch=True)
        if extra == "lily":  # a lily pad over the door
            c.ell(w / 2 - 0.5, 50, 5, 2, rgb("#5aa85a"))
            c.dot(w // 2, 49, rgb("#ff9fc2"))
        if extra == "honey":
            c.ell(w / 2 - 0.5, 30, 5, 4, rgb("#f2b84a"))
            c.rect(w // 2 - 3, 29, 6, 1, shade(rgb("#f2b84a"), 0.3))
            c.rect(w // 2 - 3, 31, 6, 1, shade(rgb("#f2b84a"), 0.3))
        return c.finish()
    return build


BUILDERS = {
    "store": b_store, "bakery": b_bakery, "forge": b_forge, "carpenter": b_carpenter, "inn": b_inn,
    "townhall": b_townhall, "museum": b_museum, "apothecary": b_apothecary, "fishshack": b_fishshack,
    "home_thistle": b_home(("#c9c2b5", "#6b7a5a", "#5a3a52", "moss")),
    "home_pebble": b_home(("#a9d4b0", "#3f8f86", "#6b4630", "lily")),
    "home_maple": b_home(("#f6dc9a", "#c9644a", "#8a5e3a", "honey")),
}


# ------------------------------------------------------------------- props

def make_props():
    frames = []
    for draw in (p_fountain, p_bench, p_lamp, p_telescope, p_board, p_hive, p_lumber, p_barrel, p_crate, p_signpost, p_planter, p_bandstand):
        c = Canvas(32, 32)
        draw(c)
        frames.append(c.finish())
    save(sheet(frames), "town_props.png")


def p_fountain(c):
    stone = rgb("#c8bba8")
    c.ell(15.5, 22, 15, 8, stone)
    c.ell(15.5, 21, 12, 5.5, rgb("#5aa6dc"))
    c.rect(14, 8, 4, 14, stone)
    c.ell(15.5, 9, 6, 2.5, stone)
    c.ell(15.5, 8, 4, 1.5, rgb("#5aa6dc"))
    c.dot(15, 4, rgb("#bfe6ff"))
    c.dot(16, 5, rgb("#bfe6ff"))
    c.dot(12, 7, rgb("#bfe6ff"))
    c.dot(19, 7, rgb("#bfe6ff"))
    c.dot(10, 20, rgb("#ffd24a"))  # coins in the water
    c.dot(20, 22, rgb("#ffd24a"))


def p_bench(c):
    wood, iron = rgb("#a8744a"), rgb("#4f4a4a")
    c.rect(2, 20, 28, 3, wood)
    c.rect(2, 14, 28, 2, wood)
    c.rect(2, 17, 28, 2, wood)
    for x in (4, 26):
        c.rect(x, 23, 2, 8, iron)
        c.rect(x, 13, 2, 8, iron)


def p_lamp(c):
    iron = rgb("#3f3a46")
    c.rect(15, 10, 2, 21, iron)
    c.rect(13, 30, 6, 2, iron)
    c.rect(12, 4, 8, 7, rgb("#ffe07a"))
    c.rect(11, 3, 10, 1, iron)
    c.rect(11, 11, 10, 1, iron)
    c.rect(15, 1, 2, 2, iron)


def p_telescope(c):
    brass = rgb("#d9b25a")
    c.rect(15, 18, 2, 13, rgb("#6b4630"))
    c.rect(11, 29, 10, 2, rgb("#6b4630"))
    for i in range(12):
        c.rect(9 + i, 15 - i // 2, 2, 4, brass if i < 9 else shade(brass, 0.2))


def p_board(c):
    wood = rgb("#8a6238")
    c.rect(5, 6, 22, 16, wood)
    c.rect(7, 8, 18, 12, rgb("#d9b88a"))
    c.rect(9, 10, 6, 4, WHITE)
    c.rect(17, 11, 6, 5, rgb("#fff3a0"))
    c.rect(10, 15, 5, 4, rgb("#ffd9ea"))
    for x in (7, 23):
        c.rect(x, 22, 2, 9, wood)
    c.rect(4, 4, 24, 2, shade(wood, 0.2))


def p_hive(c):
    honey = rgb("#f2b84a")
    c.rect(10, 26, 12, 5, rgb("#8a6238"))
    for i, w in enumerate((8, 11, 12, 11, 8)):
        c.rect(16 - w, 6 + i * 4, w * 2, 4, honey if i % 2 == 0 else shade(honey, 0.15))
    c.rect(14, 22, 4, 3, rgb("#5a3a20"))
    c.dot(24, 8, rgb("#2e2a20"))  # a bee
    c.dot(25, 7, WHITE)


def p_lumber(c):
    log = rgb("#a8744a")
    for i, (y, x0, x1) in enumerate(((24, 2, 30), (18, 4, 28), (12, 8, 24))):
        c.rect(x0, y, x1 - x0, 6, log if i % 2 == 0 else shade(log, 0.1))
        c.ell(x0, y + 2.5, 2.5, 3, rgb("#e0b884"))
        c.ell(x1 - 1, y + 2.5, 2.5, 3, rgb("#e0b884"))


def p_barrel(c):
    wood = rgb("#9a6a40")
    c.rect(9, 12, 14, 19, wood)
    c.ell(15.5, 12, 7, 2.5, shade(wood, 0.1))
    for y in (15, 26):
        c.rect(9, y, 14, 2, rgb("#5a5050"))


def p_crate(c):
    wood = rgb("#b98a55")
    c.rect(7, 14, 18, 17, wood)
    c.rect(7, 14, 18, 2, shade(wood, 0.2))
    for d in range(16):
        c.dot(8 + d, 16 + d, shade(wood, 0.3))
    c.ell(13, 12, 3, 2.2, rgb("#e0443a"))  # apples on top
    c.ell(19, 12, 3, 2.2, rgb("#e0443a"))


def p_signpost(c):
    wood = rgb("#8a6238")
    c.rect(15, 8, 2, 23, wood)
    c.rect(7, 9, 18, 6, light(wood, 0.25))
    c.tri(15.5, 17, 4, 5, light(wood, 0.25))  # an arrow pointing down the trail
    c.rect(9, 11, 9, 1, shade(wood, 0.3))


def p_planter(c):
    c.rect(6, 20, 20, 11, rgb("#b98a55"))
    c.rect(5, 19, 22, 2, rgb("#8a6238"))
    for x, colour in ((9, "#ff8fb3"), (14, "#ffd24a"), (19, "#b9a0ff"), (23, "#ff8fb3")):
        c.ell(x, 16, 3, 3, rgb("#5aa85a"))
        c.ell(x, 14, 1.6, 1.6, rgb(colour))


def p_bandstand(c):
    """Two tiles wide: a little round bandstand with a pointed roof."""
    wood, roof, trim = rgb("#f3ead8"), rgb("#c9644a"), rgb("#8a5e3a")
    c.ell(15.5, 27, 15, 4.5, rgb("#c8bba8"))  # the stone floor
    c.ell(15.5, 26, 14, 3.5, rgb("#e0d6c4"))
    for x in (2, 9, 21, 28):
        c.rect(x, 12, 2, 15, wood)
    c.rect(2, 21, 28, 1, trim)  # railing
    c.rect(2, 23, 28, 1, trim)
    c.tri(15.5, 0, 16, 12, roof)
    c.rect(0, 11, 32, 2, shade(roof, 0.2))
    c.rect(15, 0, 2, 2, rgb("#ffd24a"))
    for x in range(1, 31, 4):
        c.rect(x, 13, 2, 1, rgb("#fbeed3"))


# ---------------------------------------------------------------- the folk

FOLK = {  # body clothes, face/fur, extra drawing
    "juniper": ("#f3b0c3", "#f6efe2"),
    "flint": ("#7a5234", "#8f8a90"),
    "marlow": ("#f2c84a", "#9a6a40"),
    "birch": ("#4f9e5a", "#a8744a"),
    "sage": ("#6fae7a", "#d9a86a"),
    "quill": ("#8a6a4a", "#b08a5a"),
    "clementine": ("#5a6aa8", "#8fbf6a"),
    "rosie": ("#fbeed3", "#e88a3a"),
    "keeper_town": ("#e0d0a0", "#9a6a40"),
}


def make_folk():
    for who, (clothes, face) in FOLK.items():
        c = Canvas(16, 24)
        c.rect(4, 20, 3, 3, rgb("#6b4a36"))
        c.rect(9, 20, 3, 3, rgb("#6b4a36"))
        c.rect(4, 13, 8, 7, rgb(clothes))
        c.rect(3, 13, 1, 5, rgb(clothes))
        c.rect(12, 13, 1, 5, rgb(clothes))
        c.rect(4, 6, 8, 7, rgb(face))
        FEATURES[who](c, rgb(face), rgb(clothes))
        c.face(5, 8, happy=who != "quill", gap=5)
        save(c.finish(), "keeper_town.png" if who == "keeper_town" else "villager_%s.png" % who)


def f_juniper(c, face, clothes):  # a rabbit: long ears, a white apron
    c.rect(5, 0, 2, 6, face)
    c.rect(9, 0, 2, 6, face)
    c.dot(5, 2, rgb("#ffb8c8"))
    c.dot(10, 2, rgb("#ffb8c8"))
    c.rect(5, 14, 6, 6, WHITE)
    c.dot(7, 11, rgb("#ff9fc2"))


def f_flint(c, face, clothes):  # a badger: a white stripe down the nose, a leather apron
    c.rect(7, 6, 2, 7, WHITE)
    c.rect(4, 6, 1, 3, rgb("#4a4550"))
    c.rect(11, 6, 1, 3, rgb("#4a4550"))
    c.rect(5, 15, 6, 5, rgb("#5a3a20"))


def f_marlow(c, face, clothes):  # an otter in a sailor's cap and a raincoat
    c.rect(3, 4, 10, 2, rgb("#2f3f6a"))
    c.rect(4, 3, 8, 1, WHITE)
    c.rect(6, 10, 4, 2, rgb("#e9dcc4"))
    c.dot(3, 9, rgb("#c8b8a0"))
    c.dot(12, 9, rgb("#c8b8a0"))


def f_birch(c, face, clothes):  # a beaver: big front teeth, a red flannel shirt
    c.rect(7, 11, 2, 2, WHITE)
    c.rect(3, 13, 1, 5, rgb("#c0503a"))
    c.rect(12, 13, 1, 5, rgb("#c0503a"))
    c.rect(4, 5, 8, 1, rgb("#ffd24a"))  # a carpenter's pencil hat brim
    c.rect(5, 4, 6, 1, rgb("#ffd24a"))


def f_sage(c, face, clothes):  # a deer: little antlers, a leafy robe
    for x in (5, 10):
        c.rect(x, 2, 1, 4, rgb("#8a6238"))
        c.dot(x - 1 if x == 5 else x + 1, 3, rgb("#8a6238"))
    c.dot(6, 12, WHITE)
    c.dot(9, 12, WHITE)
    c.rect(4, 17, 8, 1, rgb("#4f8f5a"))


def f_quill(c, face, clothes):  # an owl in round spectacles and a waistcoat
    c.rect(4, 5, 2, 2, face)
    c.rect(10, 5, 2, 2, face)
    c.rect(4, 7, 3, 3, rgb("#fbeed3"))
    c.rect(9, 7, 3, 3, rgb("#fbeed3"))
    c.dot(7, 10, rgb("#f2b84a"))
    c.rect(7, 14, 2, 6, rgb("#fbeed3"))


def f_clementine(c, face, clothes):  # a tortoise: a top hat, a mayor's sash
    c.rect(5, 1, 6, 4, rgb("#2e2a30"))
    c.rect(4, 5, 8, 1, rgb("#2e2a30"))
    c.rect(5, 3, 6, 1, rgb("#e0605a"))
    for i in range(6):
        c.dot(4 + i, 13 + i, rgb("#ffd24a"))
    c.rect(2, 15, 1, 4, rgb("#8a6a3a"))  # the shell's edge
    c.rect(13, 15, 1, 4, rgb("#8a6a3a"))


def f_rosie(c, face, clothes):  # a fox: pointed ears, a white muzzle, an apron
    c.rect(4, 4, 2, 2, face)
    c.rect(10, 4, 2, 2, face)
    c.dot(4, 4, rgb("#2e2a30"))
    c.dot(11, 4, rgb("#2e2a30"))
    c.rect(6, 10, 4, 3, WHITE)
    c.rect(4, 13, 8, 2, rgb("#e88a3a"))


def f_keeper(c, face, clothes):  # Bristle the hedgehog, in his shop apron
    for x in range(3, 13, 2):
        c.rect(x, 3, 1, 4, rgb("#6b4a2e"))
    c.rect(3, 6, 10, 1, rgb("#6b4a2e"))
    c.rect(6, 9, 4, 4, rgb("#f3d9b0"))
    c.rect(5, 14, 6, 6, rgb("#5aa0a0"))


FEATURES = {"juniper": f_juniper, "flint": f_flint, "marlow": f_marlow, "birch": f_birch, "sage": f_sage,
            "quill": f_quill, "clementine": f_clementine, "rosie": f_rosie, "keeper_town": f_keeper}


# ------------------------------------------------------------------- rooms
# assets/sprites/town_room_<id>.png: inside each town building, painted from
# TOWN_ROOMS in game_state.gd (wall colour, floor kind, floor map): two rows
# of wall, then the floor, with the furniture drawn where the map puts it.

def read_rooms():
    text = open(GAME_STATE).read()
    rooms = {}
    for name, wall, floor, block in re.findall(r'"(\w+)": \{"wall": "(#\w+)", "floor": "(\w+)", "map": \[(.*?)\]\}', text, re.S):
        rooms[name] = (wall, floor, re.findall(r'"([^"]*)"', block))
    return rooms


SHELF_GOODS = {  # what each room keeps on its shelves
    "store": ["#e0605a", "#ffd24a", "#5aa85a", "#7fa8e0", "#f3b0c3"],
    "bakery": ["#d9a25a", "#e9c48a", "#c98a4a", "#fbeed3"],
    "forge": ["#9aa0aa", "#c9c2b5", "#6b6a70", "#d98a4a"],
    "carpenter": ["#b07a4a", "#8a5e3a", "#d9b884", "#9aa0aa"],
    "apothecary": ["#5fbf6a", "#b9a0ff", "#e0b04a", "#7fd0e0", "#ff8fb3"],
    "museum": ["#c9c2b5", "#ffd24a", "#7fa8e0"],
    "townhall": ["#c0503a", "#4f6aa8", "#5aa85a", "#e0b04a"],
    "inn": ["#d9a25a", "#fbeed3", "#c0503a", "#8a5e3a"],
    "fishshack": ["#9fb4c8", "#f2b84a", "#5a8fc8", "#e9e4dc"],
}


def room_floor(c, kind, w, h, y0):
    """Paint the floor of a w x h tile room starting at pixel row y0."""
    base = {"planks": "#c98f55", "wood": "#b98055", "checker": "#f3e2c8", "stone": "#9a958c",
            "marble": "#e6e2da", "carpet": "#b5523f"}[kind]
    col = rgb(base)
    for y in range(h * TILE):
        for x in range(w * TILE):
            tone = col
            if kind in ("planks", "wood"):
                row = y // 8
                if y % 8 == 7 or (x + row * 11) % 32 == 0:
                    tone = shade(col, 0.22)
                elif y % 8 == 0:
                    tone = light(col, 0.1)
            elif kind == "checker":
                if ((x // 8) + (y // 8)) % 2:
                    tone = rgb("#d9b8a0")
            elif kind == "stone":
                if x % 16 == 0 or y % 12 == 0 or (y // 12 % 2 and x % 16 == 8):
                    tone = shade(col, 0.25)
            elif kind == "marble":
                if x % 16 == 0 or y % 16 == 0:
                    tone = shade(col, 0.12)
                elif (x * 7 + y * 3) % 41 == 0:
                    tone = shade(col, 0.06)
            elif kind == "carpet":
                edge = x < 3 or y < 3 or x >= w * TILE - 3 or y >= h * TILE - 3
                tone = rgb("#e0b04a") if edge else (shade(col, 0.08) if (x + y) % 6 == 0 else col)
            c.px(x, y0 + y, tone)


def room_wall(c, colour, w):
    wall = rgb(colour)
    for y in range(2 * TILE):
        for x in range(w * TILE):
            tone = wall
            if y >= 22:
                tone = shade(wall, 0.18)  # wainscot
                if x % 8 == 0:
                    tone = shade(wall, 0.3)
            elif (x + y * 3) % 23 == 0:
                tone = shade(wall, 0.06)
            if y == 21:
                tone = shade(wall, 0.4)
            if y >= 30:
                tone = rgb("#6b4630")  # skirting board
            c.px(x, y, tone)


def make_rooms_art():
    for name, (wall, floor, rows) in read_rooms().items():
        w, h = len(rows[0]), len(rows)
        rng = random.Random(name)
        c = Canvas(w * TILE, (h + 2) * TILE)
        room_wall(c, wall, w)
        for x in (w * TILE // 4, w * TILE * 3 // 4):  # windows
            if all(rows[0][min(w - 1, max(0, (x + d) // TILE))] in ".HKD" for d in (-8, 8)):
                c.rect(x - 7, 4, 14, 12, rgb("#8a5e3a"))
                c.rect(x - 5, 6, 10, 8, rgb("#bfe6ff"))
                c.rect(x, 6, 1, 8, rgb("#8a5e3a"))
        room_floor(c, floor, w, h, 2 * TILE)
        img = c.finish(outline=False, shading=False)
        drawn = set()
        for y in range(h):
            for x in range(w):
                ch = rows[y][x]
                if (x, y) in drawn or ch in ".HK":
                    continue
                run = 1
                while x + run < w and rows[y][x + run] == ch and ch in "CSFOWG":
                    run += 1
                if ch == "B":
                    drawn.add((x, y + 1))
                for i in range(run):
                    drawn.add((x + i, y))
                piece, lift = FURNITURE.get(ch, lambda r, n, g: (None, 0))(run, name, rng)
                if piece is not None:
                    img.alpha_composite(piece, (x * TILE, (y + 2) * TILE - lift))
        save(img, "town_room_%s.png" % name)


def _canvas(w, h, draw):
    c = Canvas(w, h)
    draw(c)
    return c.finish()


def fur_counter(run, room, rng):
    top, front = rgb("#c9a070"), rgb("#8a5e3a")
    if room == "inn":
        top, front = rgb("#a8744a"), rgb("#6b4630")

    def draw(c):
        c.rect(0, 2, run * TILE, 5, top)
        c.rect(0, 7, run * TILE, 9, front)
        for x in range(8, run * TILE, 16):
            c.rect(x, 9, 1, 6, shade(front, 0.25))
        if room == "store":  # a till and a jar of sweets
            c.rect(run * TILE // 2 - 12, 0, 7, 4, rgb("#5a5a66"))
            c.ell(run * TILE // 2 + 8, 1, 2.5, 2.5, rgb("#ff8fb3"))
        elif room == "bakery":
            for i in range(0, run * TILE - 8, 12):
                c.ell(i + 6, 2, 3.5, 1.8, rgb("#d9a25a"))
        elif room == "inn":
            for i in range(4, run * TILE - 4, 14):
                c.rect(i, 0, 4, 4, rgb("#fbeed3"))
                c.rect(i + 1, 0, 2, 1, WHITE)
    return _canvas(run * TILE, 16, draw), 0


def fur_shelf(run, room, rng):
    goods = SHELF_GOODS.get(room, ["#c0503a", "#4f6aa8", "#5aa85a", "#e0b04a"])
    wood = rgb("#8a5e3a")

    def draw(c):
        c.rect(0, 0, run * TILE, 28, wood)
        for y in (2, 11, 20):
            c.rect(2, y, run * TILE - 4, 7, shade(wood, 0.35))
            x = 3
            while x < run * TILE - 5:
                wid = rng.choice((2, 3, 3, 4))
                hgt = rng.choice((4, 5, 6))
                c.rect(x, y + 7 - hgt, wid, hgt, rgb(rng.choice(goods)))
                x += wid + rng.choice((0, 1, 1, 2))
    return _canvas(run * TILE, 28, draw), 12


def fur_table(run, room, rng):
    def draw(c):
        c.ell(7.5, 7, 7, 4.5, rgb("#a8744a"))
        c.rect(6, 10, 3, 6, rgb("#6b4630"))
        c.rect(4, 4, 3, 2, rgb("#fbeed3"))  # a cup
        c.rect(9, 5, 3, 2, rgb("#e0605a"))
    return _canvas(16, 16, draw), 0


def fur_chair(run, room, rng):
    def draw(c):
        c.rect(4, 2, 8, 6, rgb("#a8744a"))
        c.rect(3, 8, 10, 3, rgb("#c0503a"))
        c.rect(4, 11, 2, 5, rgb("#6b4630"))
        c.rect(10, 11, 2, 5, rgb("#6b4630"))
    return _canvas(16, 16, draw), 0


def fur_bed(run, room, rng):
    blanket = {"home_thistle": "#8a9a5a", "home_pebble": "#5aa0e0", "home_maple": "#f2b84a"}.get(room, "#d9605a")

    def draw(c):
        c.rect(1, 0, 14, 32, rgb("#8a5e3a"))
        c.rect(2, 2, 12, 28, rgb("#f6efe2"))
        c.rect(3, 3, 10, 6, WHITE)
        c.rect(2, 12, 12, 18, rgb(blanket))
        c.rect(2, 12, 12, 2, light(rgb(blanket), 0.4))
    return _canvas(16, 32, draw), 0


def fur_oven(run, room, rng):
    def draw(c):
        brick = rgb("#b5523f")
        c.rect(0, 0, run * TILE, 26, brick)
        for y in range(2, 26, 4):
            for x in range((y // 4 % 2) * 4, run * TILE, 8):
                c.rect(x, y, 1, 3, shade(brick, 0.25))
            c.rect(0, y, run * TILE, 1, shade(brick, 0.25))
        for i in range(run):
            c.ell(i * TILE + 7.5, 16, 5, 5, rgb("#2a2024"))
            c.rect(i * TILE + 3, 16, 10, 6, rgb("#2a2024"))
            c.rect(i * TILE + 5, 17, 6, 4, rgb("#f08a2e"))
            c.rect(i * TILE + 6, 19, 4, 2, rgb("#ffd24a"))
    return _canvas(run * TILE, 26, draw), 10


def fur_fire(run, room, rng):
    furnace = room == "forge"

    def draw(c):
        stone = rgb("#8f8a80") if furnace else rgb("#b9b3c4")
        c.rect(0, 0, run * TILE, 28, stone)
        for y in range(4, 28, 6):
            c.rect(0, y, run * TILE, 1, shade(stone, 0.2))
        c.rect(5, 10, run * TILE - 10, 18, rgb("#2a2024"))
        c.ell(run * TILE / 2 - 0.5, 10, run * TILE / 2 - 5, 4, rgb("#2a2024"), top_only=True)
        c.tri(run * TILE / 2 - 0.5, 14, 6, 13, rgb("#f08a2e"))
        c.tri(run * TILE / 2 - 0.5, 19, 3, 8, rgb("#ffd24a"))
        if not furnace:
            c.rect(0, 0, run * TILE, 3, rgb("#8a5e3a"))
    return _canvas(run * TILE, 28, draw), 12


def fur_barrel(run, room, rng):
    def draw(c):
        wood = rgb("#9a6a40")
        c.rect(3, 3, 10, 13, wood)
        c.ell(7.5, 3, 5, 2, shade(wood, 0.1))
        c.rect(3, 6, 10, 1, rgb("#5a5050"))
        c.rect(3, 12, 10, 1, rgb("#5a5050"))
    return _canvas(16, 16, draw), 0


def fur_plant(run, room, rng):
    def draw(c):
        c.rect(4, 14, 8, 8, rgb("#c9744a"))
        c.ell(7.5, 8, 6, 7, rgb("#5aa85a"))
        c.ell(4, 5, 2.5, 3, rgb("#6fc46a"))
    return _canvas(16, 22, draw), 6


def fur_case(run, room, rng):
    def draw(c):
        c.rect(1, 12, 14, 10, rgb("#8a5e3a"))
        c.rect(2, 1, 12, 11, rgb("#d9eef5"))
        c.rect(2, 1, 12, 1, WHITE)
        c.rect(3, 9, 10, 2, rgb("#b5523f"))  # a velvet cushion
    return _canvas(16, 22, draw), 6


def fur_anvil(run, room, rng):
    def draw(c):
        c.rect(3, 4, 11, 4, rgb("#4f4a4a"))
        c.rect(1, 4, 3, 2, rgb("#4f4a4a"))
        c.rect(6, 8, 5, 4, rgb("#4f4a4a"))
        c.rect(4, 12, 9, 4, rgb("#6b4630"))
    return _canvas(16, 16, draw), 0


def fur_bench(run, room, rng):
    def draw(c):
        wood = rgb("#b07a4a")
        c.rect(0, 4, run * TILE, 5, wood)
        c.rect(0, 4, run * TILE, 1, light(wood, 0.2))
        for x in (1, run * TILE - 3):
            c.rect(x, 9, 2, 7, shade(wood, 0.3))
        c.rect(5, 1, 9, 3, rgb("#c9c2b5"))  # a saw
        c.rect(run * TILE - 12, 2, 6, 2, rgb("#8a5e3a"))  # a plane
    return _canvas(run * TILE, 16, draw), 0


def fur_tank(run, room, rng):
    def draw(c):
        c.rect(0, 2, run * TILE, 18, rgb("#5aa6dc"))
        c.rect(0, 2, run * TILE, 2, rgb("#bfe6ff"))
        c.rect(0, 20, run * TILE, 4, rgb("#6b4630"))
        for i in range(run * 2):
            fx = 4 + i * 7
            c.ell(fx, 10 + (i % 2) * 4, 2.5, 1.5, rgb(rng.choice(["#f2b84a", "#e88a7a", "#9fb4c8"])))
        c.rect(2, 16, run * TILE - 4, 2, rgb("#5aa85a"))
    return _canvas(run * TILE, 24, draw), 8


def fur_board(run, room, rng):
    projects = run == -1

    def draw(c):
        c.rect(1, 0, 14, 12, rgb("#8a6238"))
        c.rect(2, 1, 12, 10, rgb("#d9b88a"))
        c.rect(3, 2, 4, 3, WHITE)
        c.rect(8, 3, 4, 4, rgb("#fff3a0"))
        c.rect(4, 6, 3, 3, rgb("#ffd9ea"))
    return _canvas(16, 12, draw), 8


def fur_projects(run, room, rng):
    def draw(c):
        c.rect(1, 0, 14, 12, rgb("#5a6aa8"))
        c.rect(2, 1, 12, 10, rgb("#e9e4dc"))
        c.rect(3, 3, 10, 1, rgb("#5aa85a"))
        c.rect(3, 6, 7, 1, rgb("#e0b04a"))
        c.rect(3, 9, 4, 1, rgb("#c0503a"))
    return _canvas(16, 12, draw), 8


def fur_rug(run, room, rng):
    def draw(c):
        c.ell(7.5, 8, 7.4, 5.5, rgb("#d9605a"))
        c.ell(7.5, 8, 5, 3.4, rgb("#fbe6c4"))
    return _canvas(16, 16, draw), 0


def fur_stool(run, room, rng):
    def draw(c):
        c.ell(7.5, 8, 4.5, 2.2, rgb("#c0503a"))
        c.rect(5, 10, 2, 6, rgb("#6b4630"))
        c.rect(9, 10, 2, 6, rgb("#6b4630"))
    return _canvas(16, 16, draw), 0


def fur_mat(run, room, rng):
    def draw(c):
        c.rect(1, 9, 14, 6, rgb("#7a9a5a"))
        c.rect(2, 10, 12, 4, rgb("#9ab87a"))
    return _canvas(16, 16, draw), 0


FURNITURE = {"C": fur_counter, "S": fur_shelf, "T": fur_table, "c": fur_chair, "B": fur_bed, "O": fur_oven,
             "F": fur_fire, "b": fur_barrel, "P": fur_plant, "M": fur_case, "A": fur_anvil, "W": fur_bench,
             "G": fur_tank, "N": fur_board, "J": fur_projects, "R": fur_rug, "D": fur_mat, "s": fur_stool}
