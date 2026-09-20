#!/usr/bin/env python3
"""Generate the mezarchy wallpapers (3840x2160 PNG) from hand-built SVG.

Every scene is a Python function that returns an SVG string; the SVG is
rasterised with rsvg-convert (librsvg, part of the Omarchy base install) or,
failing that, cairosvg. Fonts go through fontconfig, so "JetBrains Mono"
resolves to the JetBrainsMono Nerd Font that Omarchy ships.

    ./mezarchy_wallpapers.py                 # write every scene to configs/omarchy/branding/backgrounds/
    ./mezarchy_wallpapers.py rain skyline    # only these scenes
    ./mezarchy_wallpapers.py --out /tmp/x    # somewhere else
    ./mezarchy_wallpapers.py --svg rain      # dump the SVG instead of rendering (debugging)
    ./mezarchy_wallpapers.py --list

Scenes are seeded, so re-running reproduces the same layout. The first four
(moonrise, neon-city, minimal, terminal) were originally rendered with cairosvg;
rsvg output is visually identical but not byte-identical, so only regenerate
them on purpose. Deploy with omarchy_install_branding.sh.
"""
import argparse
import math
import random
import shutil
import subprocess
import sys
from pathlib import Path

W, H = 3840, 2160
C = dict(  # tokyo-night
    bg="#1a1b26", bg_dark="#16161e", bg_hl="#292e42", gutter="#3b4261",
    comment="#565f89", fg="#c0caf5", fg_dark="#a9b1d6",
    blue="#7aa2f7", cyan="#7dcfff", purple="#9d7cd8", magenta="#bb9af7",
    orange="#ff9e64", yellow="#e0af68", green="#9ece6a", teal="#1abc9c", red="#f7768e",
)
FONT = "JetBrainsMono Nerd Font, JetBrains Mono, monospace"
DEFAULT_OUT = Path(__file__).resolve().parent / "configs/omarchy/branding/backgrounds"


def svg(body, defs=""):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" '
            f'viewBox="0 0 {W} {H}"><defs>{defs}</defs>{body}</svg>')


def col(c):
    """Palette key or literal colour."""
    return C.get(c, c)


def esc(s):
    return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def text(x, y, size, spans, weight=500, anchor="start", opacity=1.0, extra=""):
    """A <text> made of (colour, string) spans. Spaces are preserved."""
    inner = "".join(f'<tspan fill="{col(c)}">{esc(s)}</tspan>' for c, s in spans)
    return (f'<text x="{x:.0f}" y="{y:.0f}" font-family="{FONT}" font-size="{size}" font-weight="{weight}" '
            f'text-anchor="{anchor}" opacity="{opacity}" xml:space="preserve" {extra}>{inner}</text>')


def mark(cx, cy, size, stroke, colour="url(#markGrad)"):
    """The mezarchy mark: a lowercase m drawn as two arches over three legs."""
    s = size / 100.0
    x0, x1, x2 = cx - 40 * s, cx, cx + 40 * s
    top, base = cy - 18 * s, cy + 38 * s
    r = 20 * s
    d = (f"M {x0} {base} L {x0} {top} "
         f"A {r} {r} 0 0 1 {x1} {top} L {x1} {base} "
         f"M {x1} {top} A {r} {r} 0 0 1 {x2} {top} L {x2} {base}")
    return (f'<path d="{d}" fill="none" stroke="{colour}" stroke-width="{stroke}" '
            f'stroke-linecap="round" stroke-linejoin="round"/>')


MARK_GRAD = (f'<linearGradient id="markGrad" x1="0" y1="0" x2="1" y2="1">'
             f'<stop offset="0" stop-color="{C["cyan"]}"/>'
             f'<stop offset="0.5" stop-color="{C["blue"]}"/>'
             f'<stop offset="1" stop-color="{C["magenta"]}"/></linearGradient>')


def stars(rng, n, ymax, colours=("fg", "blue", "magenta")):
    out = []
    for _ in range(n):
        x, y = rng.uniform(0, W), rng.uniform(0, ymax) ** 1.0
        r = rng.choice([1.5, 2, 2, 2.5, 3, 4])
        o = rng.uniform(0.15, 0.8) * (1 - y / ymax * 0.7)
        out.append(f'<circle cx="{x:.0f}" cy="{y:.0f}" r="{r}" fill="{C[rng.choice(colours)]}" opacity="{o:.2f}"/>')
    return "".join(out)


def ridge(rng, base, amp, rough, octaves=6):
    phases = [rng.uniform(0, 1000) for _ in range(octaves)]
    pts = []
    for i in range(0, W + 41, 40):
        y = 0
        for o in range(octaves):
            f = rough * (2 ** o)
            y += math.sin(i * f + phases[o]) * amp / (1.9 ** o)
            y += math.sin(i * f * 1.37 + phases[o] * 0.7) * amp / (2.3 ** o)
        pts.append((i, base + y))
    d = "M 0 %d " % H + " ".join(f"L {x} {y:.0f}" for x, y in pts) + f" L {W} {H} Z"
    return d


# ---------------------------------------------------------------- shared "terminal" kit
BLOCK = {  # 5 wide x 8 tall: rows 0-1 ascender, 2-6 x-height, 7 descender
    "m": ["00000", "00000", "11110", "10101", "10101", "10101", "10101", "00000"],
    "e": ["00000", "00000", "01110", "10001", "11111", "10000", "01111", "00000"],
    "z": ["00000", "00000", "11111", "00010", "00100", "01000", "11111", "00000"],
    "a": ["00000", "00000", "01110", "00001", "01111", "10001", "01111", "00000"],
    "r": ["00000", "00000", "10111", "11000", "10000", "10000", "10000", "00000"],
    "c": ["00000", "00000", "01111", "10000", "10000", "10000", "01111", "00000"],
    "h": ["10000", "10000", "10110", "11001", "10001", "10001", "10001", "00000"],
    "y": ["00000", "00000", "10001", "10001", "10001", "01111", "00001", "01110"],
}
LOGO_WORD = "mezarchy"


def logo_width(px):
    return len(LOGO_WORD) * 6 * px - px


def block_logo(ox, oy, px, grad_id="blu"):
    """Pixel-block logotype with a drop shadow and a cyan->blue->magenta gradient
    spanning the whole word. Returns (defs, body)."""
    total_w = logo_width(px)
    cells = []
    for i, ch in enumerate(LOGO_WORD):
        for r, row in enumerate(BLOCK[ch]):
            for c, bit in enumerate(row):
                if bit == "1":
                    cells.append((ox + (i * 6 + c) * px, oy + r * px))
    sh = max(4, round(px * 12 / 44))
    body = "".join(f'<rect x="{x + sh:.0f}" y="{y + sh:.0f}" width="{px - 3}" height="{px - 3}" fill="{C["bg_hl"]}"/>'
                   for x, y in cells)
    body += "".join(f'<rect x="{x:.0f}" y="{y:.0f}" width="{px - 3}" height="{px - 3}" rx="2" fill="url(#{grad_id})"/>'
                    for x, y in cells)
    defs = (f'<linearGradient id="{grad_id}" gradientUnits="userSpaceOnUse" x1="{ox}" y1="0" x2="{ox + total_w}" y2="0">'
            f'<stop offset="0" stop-color="{C["cyan"]}"/><stop offset="0.5" stop-color="{C["blue"]}"/>'
            f'<stop offset="1" stop-color="{C["magenta"]}"/></linearGradient>')
    return defs, body


def prompt(x, y, fs, cmd, cwd="~", cursor=True):
    """`mez@arch ~ ❯ cmd` with a block cursor."""
    spans = [("green", "mez"), ("comment", "@"), ("cyan", "arch"), ("comment", f" {cwd} "),
             ("magenta", "❯ "), ("fg", cmd)]
    body = text(x, y, fs, spans)
    if cursor:
        cw = fs * 0.6
        n = len(f"mez@arch {cwd} ❯ {cmd}")
        body += (f'<rect x="{x + cw * n + 16:.0f}" y="{y - fs * 0.8:.0f}" width="{cw * 0.9:.0f}" '
                 f'height="{fs:.0f}" fill="{C["fg"]}" opacity="0.85"/>')
    return body


def swatches(x, y, w=90, h=46, gap=20):
    keys = ["red", "orange", "yellow", "green", "teal", "cyan", "blue", "magenta"]
    return "".join(f'<rect x="{x + i * (w + gap):.0f}" y="{y:.0f}" width="{w}" height="{h}" rx="6" fill="{C[k]}"/>'
                   for i, k in enumerate(keys))


def scanlines(opacity=0.12):
    return "".join(f'<rect y="{y}" width="{W}" height="2" fill="#000" opacity="{opacity}"/>' for y in range(0, H, 8))


def logo_stack(oy, px=44, cmd="welcome home", cwd="~", with_swatches=True):
    """Logo + prompt + swatches centred horizontally, top edge at oy (the layout
    of the original terminal wallpaper). Returns (defs, body, bottom_y)."""
    ox = (W - logo_width(px)) / 2
    defs, body = block_logo(ox, oy, px)
    ty = oy + 8 * px + 200
    body += prompt(ox, ty, 64, cmd, cwd)
    bottom = ty
    if with_swatches:
        body += swatches(ox, ty + 130)
        bottom = ty + 130 + 46
    return defs, body, bottom


# ---------------------------------------------------------------- 1. moonrise
def moonrise():
    rng = random.Random(7)
    defs = MARK_GRAD + (
        f'<linearGradient id="sky" x1="0" y1="0" x2="0" y2="1">'
        f'<stop offset="0" stop-color="{C["bg_dark"]}"/><stop offset="0.55" stop-color="{C["bg"]}"/>'
        f'<stop offset="1" stop-color="#2a2342"/></linearGradient>'
        f'<radialGradient id="glow" cx="0.5" cy="0.5" r="0.5">'
        f'<stop offset="0" stop-color="{C["magenta"]}" stop-opacity="0.35"/>'
        f'<stop offset="0.4" stop-color="{C["purple"]}" stop-opacity="0.12"/>'
        f'<stop offset="1" stop-color="{C["purple"]}" stop-opacity="0"/></radialGradient>'
    )
    mx, my = W * 0.68, H * 0.36
    body = f'<rect width="{W}" height="{H}" fill="url(#sky)"/>' + stars(rng, 420, H * 0.7)
    body += f'<circle cx="{mx}" cy="{my}" r="760" fill="url(#glow)"/>'
    body += f'<circle cx="{mx}" cy="{my}" r="210" fill="{C["fg"]}" opacity="0.92"/>'
    body += f'<circle cx="{mx + 70}" cy="{my - 40}" r="190" fill="#2a2342" opacity="0.18"/>'
    layers = [(H * 0.58, 150, 0.0016, "#3b3563"), (H * 0.66, 130, 0.0021, "#312d54"),
              (H * 0.73, 110, 0.0026, "#282643"), (H * 0.80, 80, 0.003, "#1f1e33")]
    for base, amp, rough, colr in layers:
        body += f'<path d="{ridge(rng, base, amp, rough)}" fill="{colr}"/>'
    lake = H * 0.86
    body += f'<rect y="{lake}" width="{W}" height="{H - lake}" fill="{C["bg_dark"]}"/>'
    body += f'<rect y="{lake}" width="{W}" height="4" fill="{C["magenta"]}" opacity="0.12"/>'
    for i in range(46):  # lake reflection shimmer
        y = lake + 30 + i * 5.5 + rng.uniform(-4, 4)
        w = rng.uniform(120, 420) * max(0.2, 1 - i / 50)
        body += (f'<rect x="{mx - w / 2 + rng.uniform(-60, 60):.0f}" y="{y:.0f}" width="{w:.0f}" height="4" rx="2" '
                 f'fill="{C["fg"]}" opacity="{rng.uniform(0.08, 0.3):.2f}"/>')
    body += mark(250, H - 150, 90, 14)
    body += (f'<text x="335" y="{H - 118}" font-family="{FONT}" font-weight="800" font-size="80" '
             f'fill="{C["fg"]}" letter-spacing="4">mezarchy</text>')
    return svg(body, defs)


# ---------------------------------------------------------------- 2. neon city
def neon_city():
    rng = random.Random(21)
    defs = MARK_GRAD + (
        f'<linearGradient id="sky2" x1="0" y1="0" x2="0" y2="1">'
        f'<stop offset="0" stop-color="{C["bg_dark"]}"/><stop offset="0.7" stop-color="#241f3a"/>'
        f'<stop offset="1" stop-color="#3a2548"/></linearGradient>'
        f'<linearGradient id="haze" x1="0" y1="0" x2="0" y2="1">'
        f'<stop offset="0" stop-color="{C["magenta"]}" stop-opacity="0"/>'
        f'<stop offset="1" stop-color="{C["magenta"]}" stop-opacity="0.18"/></linearGradient>'
        f'<radialGradient id="signGlow" cx="0.5" cy="0.5" r="0.5">'
        f'<stop offset="0" stop-color="{C["magenta"]}" stop-opacity="0.22"/>'
        f'<stop offset="1" stop-color="{C["magenta"]}" stop-opacity="0"/></radialGradient>'
    )
    body = f'<rect width="{W}" height="{H}" fill="url(#sky2)"/>' + stars(rng, 120, H * 0.35)
    body += f'<rect y="{H * 0.45}" width="{W}" height="{H * 0.55}" fill="url(#haze)"/>'

    sign_building = None
    layers = [(0.42, "#2c2a4a", 0.25, 60, 160), (0.55, "#22223a", 0.45, 90, 230), (0.70, C["bg_dark"], 0.8, 130, 320)]
    for li, (hmin, colr, lit, wmin, wmax) in enumerate(layers):
        x = -rng.uniform(0, 100)
        while x < W:
            bw = rng.uniform(wmin, wmax)
            top = H * rng.uniform(hmin * 0.55, hmin * 1.05) if li < 2 else H * rng.uniform(0.48, 0.80)
            body += f'<rect x="{x:.0f}" y="{top:.0f}" width="{bw:.0f}" height="{H - top:.0f}" fill="{colr}"/>'
            if li == 2 and rng.random() < 0.3:
                body += f'<rect x="{x + bw * 0.4:.0f}" y="{top - 90:.0f}" width="6" height="90" fill="{colr}"/>'
                body += f'<circle cx="{x + bw * 0.4 + 3:.0f}" cy="{top - 94:.0f}" r="7" fill="{C["red"]}"/>'
            if li == 2 and sign_building is None and x > W * 0.62 and bw > 200:
                top = min(top, H * 0.36)
                body += f'<rect x="{x:.0f}" y="{top:.0f}" width="{bw:.0f}" height="{H - top:.0f}" fill="{colr}"/>'
                sign_building = (x, top, bw)
            cols = max(2, int(bw // (26 + li * 8)))
            gap = bw / cols
            wy = top + 30
            while wy < H - 20:
                floor_on = rng.random() < (0.55 if li == 2 else 0.9)
                for c in range(cols):
                    if floor_on and rng.random() < lit * 0.3:
                        wc = rng.choice(["yellow", "yellow", "cyan", "blue", "magenta", "orange"])
                        body += (f'<rect x="{x + c * gap + gap * 0.25:.0f}" y="{wy:.0f}" width="{gap * 0.5:.0f}" '
                                 f'height="{10 + li * 6}" fill="{C[wc]}" opacity="{rng.uniform(0.25, 0.85) * (0.5 + li * 0.25):.2f}"/>')
                wy += 28 + li * 14
            x += bw + rng.uniform(0, 40)

    # vertical neon sign on a foreground building
    sx, stop, sbw = sign_building if sign_building else (W * 0.72, H * 0.4, 300)
    px = sx + sbw + 20
    letters = "mezarchy"
    lh = 118
    ph = lh * len(letters) + 60
    py = max(160, stop + 40)
    body += f'<rect x="{px - 10}" y="{py - 20}" width="10" height="16" fill="{C["gutter"]}"/>'
    body += f'<rect x="{px}" y="{py}" width="150" height="{ph}" rx="14" fill="#15141f" stroke="{C["gutter"]}" stroke-width="6"/>'
    for i, ch in enumerate(letters):
        ty = py + 110 + i * lh
        for sw, op in [(48, 0.07), (30, 0.12), (16, 0.25), (8, 0.5)]:
            body += (f'<text x="{px + 75}" y="{ty}" text-anchor="middle" font-family="{FONT}" font-weight="800" '
                     f'font-size="104" fill="none" stroke="{C["magenta"]}" stroke-width="{sw}" '
                     f'stroke-linejoin="round" opacity="{op}">{ch}</text>')
        body += (f'<text x="{px + 75}" y="{ty}" text-anchor="middle" font-family="{FONT}" font-weight="800" '
                 f'font-size="104" fill="#f3e8ff">{ch}</text>')
    body += f'<ellipse cx="{px + 75}" cy="{py + ph / 2}" rx="520" ry="{ph * 0.75}" fill="url(#signGlow)"/>'

    for _ in range(1400):  # rain
        x, y = rng.uniform(-200, W), rng.uniform(-100, H)
        L = rng.uniform(30, 110)
        body += (f'<line x1="{x:.0f}" y1="{y:.0f}" x2="{x + L * 0.18:.0f}" y2="{y + L:.0f}" '
                 f'stroke="{C["fg_dark"]}" stroke-width="{rng.choice([1.5, 2, 2.5])}" opacity="{rng.uniform(0.05, 0.22):.2f}"/>')
    body += f'<rect y="{H - 70}" width="{W}" height="70" fill="#0f0f16"/>'  # wet street
    for _ in range(90):
        c = rng.choice(["magenta", "cyan", "yellow", "blue"])
        body += (f'<rect x="{rng.uniform(0, W):.0f}" y="{H - rng.uniform(10, 60):.0f}" width="{rng.uniform(30, 180):.0f}" '
                 f'height="4" rx="2" fill="{C[c]}" opacity="{rng.uniform(0.1, 0.4):.2f}"/>')
    return svg(body, defs)


# ---------------------------------------------------------------- 3. minimal
def minimal():
    defs = MARK_GRAD + (
        f'<radialGradient id="v" cx="0.5" cy="0.45" r="0.75">'
        f'<stop offset="0" stop-color="{C["bg"]}"/><stop offset="1" stop-color="{C["bg_dark"]}"/></radialGradient>'
    )
    body = f'<rect width="{W}" height="{H}" fill="url(#v)"/>'
    step = 64
    for gx in range(step // 2, W, step):
        for gy in range(step // 2, H, step):
            dx, dy = (gx - W / 2) / W, (gy - H * 0.45) / H
            dist = math.hypot(dx, dy)
            o = max(0.0, 0.45 - dist * 0.6)
            if o > 0.01:
                body += f'<circle cx="{gx}" cy="{gy}" r="3" fill="{C["comment"]}" opacity="{o:.2f}"/>'
    cy = H * 0.43
    body += mark(W / 2, cy - 40, 520, 64)
    body += (f'<text x="{W / 2 + 18}" y="{cy + 420}" text-anchor="middle" font-family="{FONT}" font-weight="300" '
             f'font-size="120" fill="{C["fg"]}" letter-spacing="36">mezarchy</text>')
    return svg(body, defs)


# ---------------------------------------------------------------- 4. terminal
def terminal():
    body = f'<rect width="{W}" height="{H}" fill="{C["bg_dark"]}"/>' + scanlines()
    defs, stack, _ = logo_stack(H * 0.27)
    return svg(body + stack, defs)


# ---------------------------------------------------------------- 5. rain (code rain)
def rain():
    rng = random.Random(42)
    glyphs = "01{}<>/\\$#%&@~^;:=+-*[]()|!?ABCDEF0123456789"
    hues = ["green", "green", "cyan", "blue", "magenta", "teal"]
    fs, col_w = 34, 40
    body = f'<rect width="{W}" height="{H}" fill="{C["bg_dark"]}"/>'
    for cx in range(20, W, col_w):
        for _ in range(rng.randint(1, 2)):
            n = rng.randint(8, 42)
            y0 = rng.uniform(-n * fs, H)
            hue = rng.choice(hues)
            base_op = rng.uniform(0.3, 0.65)
            for i in range(n):
                y = y0 + i * fs
                if y < 0 or y > H + fs:
                    continue
                head = i == n - 1
                t = i / (n - 1) if n > 1 else 1
                o = min(0.9, base_op + 0.3) if head else base_op * (0.12 + 0.88 * t)
                body += (f'<text x="{cx}" y="{y:.0f}" font-family="{FONT}" font-size="{fs}" font-weight="500" '
                         f'fill="{C["fg" if head else hue]}" opacity="{o:.2f}">{esc(rng.choice(glyphs))}</text>')
    # a dark pool behind the logo so it stays readable over the rain
    defs = (f'<radialGradient id="pool" cx="0.5" cy="0.42" r="0.55">'
            f'<stop offset="0" stop-color="{C["bg_dark"]}" stop-opacity="0.92"/>'
            f'<stop offset="0.6" stop-color="{C["bg_dark"]}" stop-opacity="0.55"/>'
            f'<stop offset="1" stop-color="{C["bg_dark"]}" stop-opacity="0"/></radialGradient>')
    body += f'<rect width="{W}" height="{H}" fill="url(#pool)"/>' + scanlines()
    d, stack, _ = logo_stack(H * 0.27, cmd="tail -f /dev/matrix")
    return svg(body + stack, defs + d)


# ---------------------------------------------------------------- 6. skyline (pixel city at night)
def skyline():
    rng = random.Random(9)
    g = 16  # pixel grid
    defs = (f'<linearGradient id="sky3" x1="0" y1="0" x2="0" y2="1">'
            f'<stop offset="0" stop-color="{C["bg_dark"]}"/><stop offset="0.6" stop-color="#1b1b2e"/>'
            f'<stop offset="1" stop-color="#2a2342"/></linearGradient>'
            f'<linearGradient id="haze3" x1="0" y1="0" x2="0" y2="1">'
            f'<stop offset="0" stop-color="{C["magenta"]}" stop-opacity="0"/>'
            f'<stop offset="1" stop-color="{C["magenta"]}" stop-opacity="0.14"/></linearGradient>'
            f'<radialGradient id="moonGlow" cx="0.5" cy="0.5" r="0.5">'
            f'<stop offset="0" stop-color="{C["fg"]}" stop-opacity="0.16"/>'
            f'<stop offset="1" stop-color="{C["fg"]}" stop-opacity="0"/></radialGradient>')
    body = f'<rect width="{W}" height="{H}" fill="url(#sky3)"/>'
    for _ in range(260):  # pixel stars
        x, y = rng.randrange(0, W, g), rng.randrange(0, int(H * 0.55), g)
        s = rng.choice([4, 4, 6, 8])
        body += (f'<rect x="{x}" y="{y}" width="{s}" height="{s}" fill="{C[rng.choice(["fg", "fg", "blue", "magenta"])]}" '
                 f'opacity="{rng.uniform(0.15, 0.7):.2f}"/>')
    # pixel crescent moon
    mx, my, mr = W * 0.84, H * 0.17, 120
    body += f'<circle cx="{mx}" cy="{my}" r="{mr * 3.2}" fill="url(#moonGlow)"/>'
    for x in range(int(mx - mr - g), int(mx + mr + g), g):
        for y in range(int(my - mr - g), int(my + mr + g), g):
            cx, cy = x + g / 2, y + g / 2
            if math.hypot(cx - mx, cy - my) <= mr and math.hypot(cx - (mx + 52), cy - (my - 34)) > mr * 0.86:
                body += f'<rect x="{x}" y="{y}" width="{g - 2}" height="{g - 2}" fill="{C["fg"]}" opacity="0.9"/>'
    body += f'<rect y="{H * 0.45}" width="{W}" height="{H * 0.55}" fill="url(#haze3)"/>'

    # skyline, far -> near; everything snapped to the pixel grid
    layers = [  # base_y, colour, min/max height in cells, min/max width in cells, window prob, window opacity
        (H * 0.72, "#23243d", 10, 27, 6, 16, 0.18, 0.35),
        (H * 0.81, "#1c1c2f", 12, 40, 7, 20, 0.28, 0.6),
        (H * 0.90, "#101018", 14, 46, 8, 24, 0.35, 0.9),
    ]
    for li, (base, colr, hmin, hmax, wmin, wmax, p, wop) in enumerate(layers):
        base = int(base // g * g)
        x = -rng.randint(0, 6) * g
        while x < W:
            bw = rng.randint(wmin, wmax) * g
            top = base - rng.randint(hmin, hmax) * g
            body += f'<rect x="{x}" y="{top}" width="{bw}" height="{H - top}" fill="{colr}"/>'
            if rng.random() < 0.45:  # stepped roof
                sw_ = rng.randint(2, max(2, bw // g - 2)) * g
                sx = x + rng.randint(0, (bw - sw_) // g) * g
                st = top - rng.randint(1, 5) * g
                body += f'<rect x="{sx}" y="{st}" width="{sw_}" height="{top - st + 2}" fill="{colr}"/>'
                top_ant = st
            else:
                top_ant = top
            if li == 2 and rng.random() < 0.35:  # antenna with a red beacon
                ax = x + rng.randint(1, bw // g - 2) * g
                ah = rng.randint(3, 8) * g
                body += f'<rect x="{ax + 6}" y="{top_ant - ah}" width="4" height="{ah}" fill="{colr}"/>'
                body += f'<rect x="{ax + 3}" y="{top_ant - ah - g + 4}" width="10" height="10" fill="{C["red"]}"/>'
            for wy in range(top + g, H - g, 2 * g):
                floor_on = rng.random() < 0.8
                for wx in range(x + g, x + bw - g, 2 * g):
                    if floor_on and rng.random() < p:
                        wc = rng.choice(["yellow", "yellow", "yellow", "cyan", "blue", "magenta", "orange"])
                        body += (f'<rect x="{wx}" y="{wy}" width="{g - 6}" height="{g - 6}" fill="{C[wc]}" '
                                 f'opacity="{rng.uniform(0.5, 1.0) * wop:.2f}"/>')
            x += bw + rng.choice([0, 0, g, 2 * g])
    street = int(H * 0.90 // g * g)
    body += f'<rect y="{street}" width="{W}" height="{H - street}" fill="#0c0c12"/>'
    for _ in range(70):  # wet street reflections
        c = rng.choice(["magenta", "cyan", "yellow", "blue"])
        body += (f'<rect x="{rng.randrange(0, W, g)}" y="{rng.randrange(street + g, H - g, g)}" '
                 f'width="{rng.randint(2, 10) * g}" height="4" fill="{C[c]}" opacity="{rng.uniform(0.1, 0.4):.2f}"/>')
    body += scanlines(0.10)
    d, stack, _ = logo_stack(H * 0.13, cmd="ssh city.night")
    return svg(body + stack, defs + d)


# ---------------------------------------------------------------- 7. circuit (logo silkscreened on a chip)
def circuit():
    rng = random.Random(5)
    chip_w, chip_h = 2560, 1180
    cx0, cy0 = (W - chip_w) / 2, (H - chip_h) / 2 - 40
    cx1, cy1 = cx0 + chip_w, cy0 + chip_h
    lit_cols = ["cyan", "magenta", "blue", "green", "teal"]

    def inside_chip(x, y, m=60):
        return cx0 - m < x < cx1 + m and cy0 - m < y < cy1 + m

    def trace(x, y, dx, dy, segs):
        """Straight run, then alternating 45-degree jogs and straight runs."""
        pts = [(x, y)]
        d = rng.uniform(80, 340)
        x, y = x + dx * d, y + dy * d
        pts.append((x, y))
        for _ in range(segs):
            s = rng.choice([-1, 1])
            d = rng.uniform(80, 420)
            nx, ny = (s, dy) if dx == 0 else (dx, s)
            x, y = x + nx * d, y + ny * d
            pts.append((x, y))
            d = rng.uniform(100, 640)
            x, y = x + dx * d, y + dy * d
            pts.append((x, y))
        return pts

    def draw_trace(pts, lit, dim=1.0):
        d = "M " + " L ".join(f"{x:.0f} {y:.0f}" for x, y in pts)
        colr = C[rng.choice(lit_cols)] if lit else C["gutter"]
        out = f'<g opacity="{dim}">'
        if lit:
            out += f'<path d="{d}" fill="none" stroke="{colr}" stroke-width="28" stroke-linejoin="round" stroke-linecap="round" opacity="0.10"/>'
        out += (f'<path d="{d}" fill="none" stroke="{colr}" stroke-width="7" stroke-linejoin="round" '
                f'stroke-linecap="round" opacity="{0.85 if lit else 0.75}"/>')
        ex, ey = pts[-1]
        out += f'<circle cx="{ex:.0f}" cy="{ey:.0f}" r="16" fill="{C["bg_dark"]}" stroke="{colr}" stroke-width="6"/>'
        if lit:
            out += f'<circle cx="{ex:.0f}" cy="{ey:.0f}" r="6" fill="{colr}"/>'
        return out + "</g>"

    body = f'<rect width="{W}" height="{H}" fill="{C["bg_dark"]}"/>'
    # sparse, faded background traces, kept off the chip
    n = 0
    while n < 40:
        x, y = rng.uniform(0, W), rng.uniform(0, H)
        dx, dy = rng.choice([(1, 0), (-1, 0), (0, 1), (0, -1)])
        pts = trace(x, y, dx, dy, rng.randint(1, 3))
        if any(inside_chip(px, py) for px, py in pts):
            continue
        body += draw_trace(pts, rng.random() < 0.1, dim=0.45)
        n += 1
    for _ in range(90):  # vias
        x, y = rng.uniform(0, W), rng.uniform(0, H)
        if not inside_chip(x, y):
            body += f'<circle cx="{x:.0f}" cy="{y:.0f}" r="9" fill="none" stroke="{C["gutter"]}" stroke-width="4" opacity="0.5"/>'
    # pins + their traces
    pin_l, pin_t, step = 60, 26, 96
    pins = []
    for x in range(int(cx0 + step), int(cx1 - step / 2), step):
        pins.append((x, cy0, 0, -1))
        pins.append((x, cy1, 0, 1))
    for y in range(int(cy0 + step), int(cy1 - step / 2), step):
        pins.append((cx0, y, -1, 0))
        pins.append((cx1, y, 1, 0))
    for x, y, dx, dy in pins:
        lit = rng.random() < 0.22
        if dx == 0:
            body += f'<rect x="{x - pin_t / 2:.0f}" y="{y if dy > 0 else y - pin_l:.0f}" width="{pin_t}" height="{pin_l}" fill="{C["gutter"]}"/>'
        else:
            body += f'<rect x="{x if dx > 0 else x - pin_l:.0f}" y="{y - pin_t / 2:.0f}" width="{pin_l}" height="{pin_t}" fill="{C["gutter"]}"/>'
        body += draw_trace(trace(x + dx * pin_l, y + dy * pin_l, dx, dy, rng.randint(1, 2)), lit)
    # chip body
    body += f'<rect x="{cx0}" y="{cy0}" width="{chip_w}" height="{chip_h}" rx="28" fill="{C["bg"]}" stroke="{C["gutter"]}" stroke-width="6"/>'
    body += (f'<rect x="{cx0 + 26}" y="{cy0 + 26}" width="{chip_w - 52}" height="{chip_h - 52}" rx="18" fill="none" '
             f'stroke="{C["bg_hl"]}" stroke-width="3"/>')
    body += f'<circle cx="{cx0 + 90}" cy="{cy0 + 90}" r="22" fill="{C["bg_dark"]}" stroke="{C["gutter"]}" stroke-width="4"/>'
    body += text(cx0 + 70, cy1 - 60, 36, [("comment", "MEZARCHY-1  ·  TOKYO NIGHT CORE")], extra='letter-spacing="6"')
    body += text(cx1 - 70, cy1 - 60, 36, [("comment", "REV 2026.09  ·  ARCH")], anchor="end", extra='letter-spacing="6"')
    # scanlines only over the chip face, like a display
    body += "".join(f'<rect x="{cx0}" y="{y}" width="{chip_w}" height="2" fill="#000" opacity="0.12"/>'
                    for y in range(int(cy0), int(cy1), 8))
    px = 44
    ox, oy = (W - logo_width(px)) / 2, cy0 + 200
    d, logo = block_logo(ox, oy, px)
    ty = oy + 8 * px + 170
    body += logo + prompt(ox, ty, 64, "cat /proc/cpuinfo", cursor=False)
    body += text(ox, ty + 90, 44, [("comment", "model name"), ("fg_dark", "   : mezarchy core @ 5.10GHz")])
    body += swatches(ox, ty + 180)
    return svg(body, d)


# ---------------------------------------------------------------- 8. horizon (synthwave grid)
def horizon():
    rng = random.Random(77)
    hy = int(H * 0.70)
    sun_cx, sun_cy, sun_r = W / 2, hy - 290, 340
    defs = (f'<linearGradient id="sky4" gradientUnits="userSpaceOnUse" x1="0" y1="0" x2="0" y2="{H}">'
            f'<stop offset="0" stop-color="{C["bg_dark"]}"/><stop offset="0.5" stop-color="#1c1a33"/>'
            f'<stop offset="{hy / H:.3f}" stop-color="#3a2548"/></linearGradient>'
            f'<linearGradient id="sun" gradientUnits="userSpaceOnUse" x1="0" y1="{sun_cy - sun_r}" x2="0" y2="{sun_cy + sun_r}">'
            f'<stop offset="0" stop-color="{C["orange"]}"/><stop offset="0.55" stop-color="{C["red"]}"/>'
            f'<stop offset="1" stop-color="{C["magenta"]}"/></linearGradient>'
            f'<radialGradient id="sunGlow" cx="0.5" cy="0.5" r="0.5">'
            f'<stop offset="0" stop-color="{C["red"]}" stop-opacity="0.35"/>'
            f'<stop offset="0.5" stop-color="{C["magenta"]}" stop-opacity="0.12"/>'
            f'<stop offset="1" stop-color="{C["magenta"]}" stop-opacity="0"/></radialGradient>'
            f'<linearGradient id="ground" x1="0" y1="0" x2="0" y2="1">'
            f'<stop offset="0" stop-color="#1a1530"/><stop offset="1" stop-color="#0d0d14"/></linearGradient>'
            f'<clipPath id="skyClip"><rect width="{W}" height="{hy}"/></clipPath>')
    body = f'<rect width="{W}" height="{H}" fill="url(#sky4)"/>' + stars(rng, 320, hy * 0.85)
    # the classic striped lower half, cut out of the disc with a mask
    stripes = ""
    y, gap, band = sun_cy - 10, 22, 6
    while y < sun_cy + sun_r:
        stripes += f'<rect x="{sun_cx - sun_r - 4}" y="{y:.0f}" width="{sun_r * 2 + 8}" height="{band:.0f}" fill="#000"/>'
        y += band + gap
        band, gap = band * 1.35, gap * 0.96
    defs += (f'<mask id="sunMask"><circle cx="{sun_cx}" cy="{sun_cy}" r="{sun_r}" fill="#fff"/>{stripes}</mask>')
    body += f'<g clip-path="url(#skyClip)">'
    body += f'<circle cx="{sun_cx}" cy="{sun_cy}" r="{sun_r * 2.4}" fill="url(#sunGlow)"/>'
    body += f'<circle cx="{sun_cx}" cy="{sun_cy}" r="{sun_r}" fill="url(#sun)" mask="url(#sunMask)"/>'
    body += "</g>"
    # ground + perspective grid
    body += f'<rect y="{hy}" width="{W}" height="{H - hy}" fill="url(#ground)"/>'
    grid = ""
    for i in range(-30, 31):
        xb = W / 2 + i * 240
        grid += f'<line x1="{W / 2}" y1="{hy}" x2="{xb:.0f}" y2="{H + 200}"/>'
    t = 0.0
    for n_ in range(1, 16):
        t = 1 - 0.78 ** n_
        yy = hy + (H - hy) * t
        grid += f'<line x1="0" y1="{yy:.0f}" x2="{W}" y2="{yy:.0f}"/>'
    body += f'<g stroke="{C["magenta"]}" stroke-width="14" opacity="0.08" clip-path="url(#groundClip)">{grid}</g>'
    body += f'<g stroke="{C["magenta"]}" stroke-width="3" opacity="0.5" clip-path="url(#groundClip)">{grid}</g>'
    defs += f'<clipPath id="groundClip"><rect y="{hy}" width="{W}" height="{H - hy}"/></clipPath>'
    body += f'<rect y="{hy - 8}" width="{W}" height="18" fill="{C["magenta"]}" opacity="0.18"/>'
    body += f'<rect y="{hy - 2}" width="{W}" height="4" fill="{C["magenta"]}" opacity="0.9"/>'
    body += scanlines(0.10)
    d, stack, _ = logo_stack(H * 0.06, cmd="drive --to horizon")
    return svg(body + stack, defs + d)


# ---------------------------------------------------------------- 9. panes (tiling terminal session)
def panes():
    rng = random.Random(13)
    fs, lh = 32, 44
    body = f'<rect width="{W}" height="{H}" fill="{C["bg_dark"]}"/>'
    margin, gap, bar_h = 60, 24, 64
    ax0, ay0, ax1, ay1 = margin, margin, W - margin, H - margin - bar_h - gap
    aw, ah = ax1 - ax0, ay1 - ay0
    split_x = ax0 + aw * 0.57
    r_split = ay0 + ah * 0.56
    l_split = ay0 + ah * 0.60
    pane_rects = {  # name: (x0, y0, x1, y1, title, focused)
        "logo": (ax0, ay0, split_x - gap / 2, l_split - gap / 2, "zsh", True),
        "git": (ax0, l_split + gap / 2, split_x - gap / 2, ay1, "git log --graph --oneline", False),
        "htop": (split_x + gap / 2, ay0, ax1, r_split - gap / 2, "htop", False),
        "hex": (split_x + gap / 2, r_split + gap / 2, ax1, ay1, "xxd /dev/mezarchy", False),
    }
    defs = ""
    content = {}
    for name, (x0, y0, x1, y1, title, focused) in pane_rects.items():
        stroke = C["green"] if focused else C["gutter"]
        body += (f'<rect x="{x0:.0f}" y="{y0:.0f}" width="{x1 - x0:.0f}" height="{y1 - y0:.0f}" rx="10" fill="{C["bg_dark"]}" '
                 f'stroke="{stroke}" stroke-width="3" opacity="{1 if focused else 0.8}"/>')
        tw = len(title) * fs * 0.6 + 40
        body += f'<rect x="{x0 + 40:.0f}" y="{y0 - 20:.0f}" width="{tw:.0f}" height="40" fill="{C["bg_dark"]}"/>'
        body += text(x0 + 60, y0 + 12, fs, [("green" if focused else "comment", title)])
        # content is clipped to the pane interior, like a real terminal
        defs += (f'<clipPath id="clip_{name}"><rect x="{x0 + 4:.0f}" y="{y0 + 30:.0f}" '
                 f'width="{x1 - x0 - 8:.0f}" height="{y1 - y0 - 50:.0f}"/></clipPath>')
        content[name] = ""

    def lines(x, y, rows, opacity=0.6):
        return "".join(text(x, y + i * lh, fs, spans, opacity=opacity) for i, spans in enumerate(rows))

    # --- htop
    x0, y0, x1, y1, *_ = pane_rects["htop"]
    rows = []
    for cpu in range(8):
        use = rng.uniform(0.05, 0.92)
        n = round(use * 40)
        bar = [("cyan", f"{cpu:>3} "), ("fg_dark", "[")]
        for i in range(40):
            if i < n:
                bar.append(("green" if i < 20 else "yellow" if i < 32 else "red", "|"))
            else:
                bar.append(("fg", " "))
        bar += [("fg_dark", "]"), ("comment", f"{use * 100:5.1f}%")]
        rows.append(bar)
    used = 21.4
    n = round(used / 64 * 40)
    rows.append([("cyan", "Mem "), ("fg_dark", "[")] + [("magenta" if i < n else "fg", "|" if i < n else " ") for i in range(40)]
                + [("fg_dark", "]"), ("comment", f"{used:.1f}G/64.0G")])
    rows.append([("cyan", "Swp "), ("fg_dark", "[")] + [("fg", " ")] * 40 + [("fg_dark", "]"), ("comment", "   0K/8.00G")])
    rows.append([])
    rows.append([("comment", "Tasks: "), ("fg", "214"), ("comment", ", "), ("fg", "412"), ("comment", " thr; "), ("green", "1 running")])
    rows.append([("comment", "Load average: "), ("fg", "0.42 0.51 0.39")])
    rows.append([("comment", "Uptime: "), ("fg", "13 days, 03:37:12")])
    rows.append([])
    procs = [("hyprland", 2.1, 1.3), ("zellij", 0.7, 0.2), ("nvim", 1.4, 0.8), ("claude", 12.6, 3.1),
              ("alacritty", 0.9, 0.5), ("herdr", 0.4, 0.3), ("fresh", 3.3, 1.9), ("zsh", 0.0, 0.1)]
    header = f'{"PID":>7} {"USER":<6}{"PRI":>4}{"NI":>4}{"VIRT":>7}{"RES":>7} S {"CPU%":>5}{"MEM%":>5} {"TIME+":>9}  Command'
    hdr_row = len(rows)
    rows.append([("fg", header)])
    for i, (pname, cpu, mem) in enumerate(procs):
        pid = rng.randint(1000, 99999)
        rows.append([("cyan", f"{pid:>7} "), ("fg_dark", f"{'mez':<6}"), ("fg", f"{20:>4}{0:>4}"),
                     ("fg_dark", f"{rng.randint(80, 999):>6}M{rng.randint(20, 400):>6}M "),
                     ("green" if cpu > 5 else "fg", " R " if cpu > 5 else " S "),
                     ("yellow" if cpu > 5 else "fg", f"{cpu:>5.1f}"), ("fg", f"{mem:>5.1f} "),
                     ("comment", f"{rng.randint(0, 9)}:{rng.randint(0, 59):02d}.{rng.randint(0, 99):02d}".rjust(9)),
                     ("fg", "  " + pname)])
    content["htop"] += (f'<rect x="{x0 + 40:.0f}" y="{y0 + 60 + hdr_row * lh + fs * 0.25:.0f}" width="{x1 - x0 - 80:.0f}" '
                        f'height="{lh}" fill="{C["bg_hl"]}" opacity="0.6"/>')
    content["htop"] += lines(x0 + 60, y0 + 60 + fs, rows)

    # --- hexdump
    x0, y0, x1, y1, *_ = pane_rects["hex"]
    rows = []
    n_rows = int((y1 - y0 - 100) // lh)
    for r in range(n_rows):
        if r == 0:
            data = list(b"mezarchy  ~  tokyo night")[:16]
        elif r == 1:
            data = list(b"welcome home, mez")[:16]
        else:
            data = [rng.choice([rng.randint(0x20, 0x7e), rng.randint(0, 255), 0, 0xff]) for _ in range(16)]
        spans = [("comment", f"{r * 16:08x}: ")]
        for i in range(0, 16, 2):
            spans.append(("blue" if (i // 2) % 2 == 0 else "cyan", f"{data[i]:02x}{data[i + 1]:02x} "))
        spans.append(("fg_dark", " " + "".join(chr(b) if 0x20 <= b < 0x7f else "." for b in data)))
        rows.append(spans)
    content["hex"] += lines(x0 + 60, y0 + 60 + fs, rows)

    # --- git log
    x0, y0, x1, y1, *_ = pane_rects["git"]
    commits = [
        ("a3f9c21", "(HEAD -> main, origin/main)", "Add five more mezarchy wallpapers"),
        ("35d8c77", "", "Rework install_aliases.sh into check/apply modes; add sshmb alias"),
        ("fb0b301", "", "Add omarchy_install_branding.sh to reproduce the mezarchy branding"),
        ("6ea301e", "", "Add hypr input.lua (Rival 300 sensitivity) to omarchy laptop setup"),
        ("0710eb0", "", "Add omarchy_laptop_setup.sh to reproduce the display + text sizing setup"),
        ("ef566e4", "", "Fix cat wrapper printing its fallback notice to stdout"),
        ("9b12e4d", "(tag: v2026.09)", "Sync AI Utilities skills and OpenCode commands"),
    ]
    rows = []
    for h, deco, msg in commits:
        spans = [("yellow", "* "), ("yellow", h + " ")]
        if deco:
            spans.append(("cyan", deco + " "))
        spans.append(("fg", msg))
        rows.append(spans)
    rows.append([])
    rows.append([("comment", "On branch "), ("green", "main"), ("comment", " · your branch is up to date with "), ("cyan", "origin/main")])
    rows.append([])
    content["git"] += lines(x0 + 60, y0 + 60 + fs, rows)
    content["git"] += prompt(x0 + 60, y0 + 60 + fs + len(rows) * lh, fs, "git push", cwd=".dotmez")

    # --- status bar (zellij-ish)
    by = ay1 + gap
    body += f'<rect x="{ax0}" y="{by}" width="{aw}" height="{bar_h}" rx="10" fill="{C["bg"]}"/>'

    def pill(x, label, fill, fg, weight=700):
        w = len(label) * fs * 0.6 + 48
        out = f'<rect x="{x:.0f}" y="{by + 10}" width="{w:.0f}" height="{bar_h - 20}" rx="8" fill="{col(fill)}"/>'
        out += text(x + w / 2, by + bar_h / 2 + fs * 0.36, fs, [(fg, label)], weight=weight, anchor="middle")
        return out, x + w + 16

    x = ax0 + 20
    for label, fill, fg in [("mezarchy", "green", "bg_dark"), ("1 zsh", "blue", "bg_dark"),
                            ("2 nvim", "bg_hl", "fg_dark"), ("3 logs", "bg_hl", "fg_dark"), ("4 ssh", "bg_hl", "fg_dark")]:
        seg, x = pill(x, label, fill, fg)
        body += seg
    body += text(ax1 - 30, by + bar_h / 2 + fs * 0.36, fs,
                 [("comment", "  tokyo-night   "), ("magenta", "NORMAL"), ("comment", "   2026-09-20   "), ("fg", "23:59")],
                 anchor="end")

    # --- logo pane
    x0, y0, x1, y1, *_ = pane_rects["logo"]
    px = 38
    lw = logo_width(px)
    ox = x0 + ((x1 - x0) - lw) / 2
    oy = y0 + 150
    d, logo = block_logo(ox, oy, px)
    ty = oy + 8 * px + 170
    content["logo"] += logo + prompt(ox, ty, 60, "zellij attach mezarchy")
    content["logo"] += swatches(ox, ty + 120)
    content["logo"] += text(ox, ty + 280, fs, [("comment", "# every pane is a home")], opacity=0.8)

    body += scanlines(0.10)
    for name, c in content.items():
        body += f'<g clip-path="url(#clip_{name})">{c}</g>'
    return svg(body, defs + d)


SCENES = {
    "mezarchy-moonrise": moonrise,
    "mezarchy-neon-city": neon_city,
    "mezarchy-minimal": minimal,
    "mezarchy-terminal": terminal,
    "mezarchy-rain": rain,
    "mezarchy-skyline": skyline,
    "mezarchy-circuit": circuit,
    "mezarchy-horizon": horizon,
    "mezarchy-panes": panes,
}


def render(svg_text, out: Path):
    if shutil.which("rsvg-convert"):
        subprocess.run(["rsvg-convert", "-w", str(W), "-h", str(H), "-o", str(out)],
                       input=svg_text.encode(), check=True)
    else:
        try:
            import cairosvg
        except ImportError:
            sys.exit("need rsvg-convert (pacman -S librsvg) or python cairosvg")
        cairosvg.svg2png(bytestring=svg_text.encode(), write_to=str(out), output_width=W, output_height=H)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("scenes", nargs="*", help="scene names (with or without the mezarchy- prefix); default all")
    ap.add_argument("--out", type=Path, default=DEFAULT_OUT, help=f"output directory (default {DEFAULT_OUT})")
    ap.add_argument("--svg", action="store_true", help="write .svg files instead of rendering PNGs")
    ap.add_argument("--list", action="store_true", help="list scene names")
    args = ap.parse_args()
    if args.list:
        print("\n".join(SCENES))
        return
    names = [n if n.startswith("mezarchy-") else f"mezarchy-{n}" for n in args.scenes] or list(SCENES)
    unknown = [n for n in names if n not in SCENES]
    if unknown:
        sys.exit(f"unknown scene(s): {', '.join(unknown)}  (try --list)")
    args.out.mkdir(parents=True, exist_ok=True)
    for name in names:
        svg_text = SCENES[name]()
        if args.svg:
            out = args.out / f"{name}.svg"
            out.write_text(svg_text)
        else:
            out = args.out / f"{name}.png"
            render(svg_text, out)
        print("wrote", out)


if __name__ == "__main__":
    main()
