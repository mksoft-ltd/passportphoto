#!/usr/bin/env python3
"""Emit the Passport Photo Studio SVG masters (icon, splash, feature graphic).

The mark is "the spec frame": a document photo card, cropped to the 35x45
passport ratio, with registration marks at its corners and a head-and-shoulders
figure sitting on the spec's eye line. It says *measured portrait* without a
camera, a booth or a shutter button — none of which are what this app does.

There is deliberately no tick, badge, rosette, star or seal anywhere in the
mark. Google Play rejected the 11 Aug 2026 listing under the Metadata policy
because the previous version's green tick badge read as approval / award
imagery. Approval-like elements must not come back into any store artwork.

Everything is derived from the constants below, so the mark can be re-tuned
without hand-editing path data. Run this, then ./render.sh.

    python3 store_assets/branding/make_branding.py

No third-party dependencies - stdlib only.
"""

from __future__ import annotations

import math
import pathlib

HERE = pathlib.Path(__file__).resolve().parent

# --- brand colours (mirror lib/app/theme.dart and ../BRAND.md) --------------
INK_TOP = "#173F8E"      # top-left of the icon plate gradient
INK = "#0C2350"          # Ink Navy - the plate, and every dark store surface
INK_DEEP = "#071634"     # bottom-right of the same gradient
BLUE = "#1E5BD8"         # Passport Blue - the figure
BLUE_DEEP = "#154BBE"    # the figure's shoulders, one step down
SKY = "#7FB0FF"          # registration marks; Passport Blue lifted onto navy
GREEN = "#12B06E"        # accent for the feature graphic's claim chip only -
                         # never as a tick, seal or badge (see module docstring)
CARD = "#FFFFFF"
CARD_TINT = "#EDF2FA"    # the card's far corner, so it is paper and not a hole
TEXT = "#EAF0FA"
TEXT_MUTED = "#9FB2CE"

# --- mark geometry, in a 1000-unit design box -------------------------------
# The card is the 35:45 passport ratio exactly - 560 x 720.
CARD_W, CARD_H = 560.0, 720.0
CARD_X, CARD_Y = 220.0, 110.0
CARD_R = 28.0

# Registration marks: an L at each card corner, set outside the card the way a
# print crop mark is.
REG_OFFSET = 46.0        # gap between the card edge and the mark
REG_ARM = 116.0          # length of each arm
REG_STROKE = 26.0

# The figure. Head height is ~72% of the card height, which is roughly what the
# specs themselves ask for, so the mark is drawn to its own rules.
HEAD_RX, HEAD_RY = 150.0, 180.0
HEAD_CX = CARD_X + CARD_W / 2
HEAD_CY = CARD_Y + CARD_H * 0.375
EYE_Y = HEAD_CY - HEAD_RY * 0.16     # where the eye line rule crosses
SHOULDER_CY = CARD_Y + CARD_H * 1.20
SHOULDER_RX, SHOULDER_RY = 330.0, 270.0

# The eye-line rule, drawn across the card and stopping either side of the head.
EYE_STROKE = 16.0
EYE_OPACITY = 0.62


def hull() -> tuple[float, float, float]:
    """Span and centre of everything drawn, strokes included.

    The registration marks are the outermost thing in the mark, so the hull is
    just their bounding box.
    """
    half = REG_STROKE / 2
    min_x = CARD_X - REG_OFFSET - half
    max_x = CARD_X + CARD_W + REG_OFFSET + half
    min_y = CARD_Y - REG_OFFSET - half
    max_y = CARD_Y + CARD_H + REG_OFFSET + half
    span = max(max_x - min_x, max_y - min_y)
    return span, (min_x + max_x) / 2, (min_y + max_y) / 2


def max_radius() -> float:
    """Distance from the mark's centre to the farthest point actually drawn.

    Round masks care about this, not about the bounding box: the corners of the
    box are empty, but the outer elbow of a registration mark is not.
    """
    _, cx, cy = hull()
    half = REG_STROKE / 2
    corners = [
        (CARD_X - REG_OFFSET - half, CARD_Y - REG_OFFSET - half),
        (CARD_X + CARD_W + REG_OFFSET + half, CARD_Y - REG_OFFSET - half),
        (CARD_X - REG_OFFSET - half, CARD_Y + CARD_H + REG_OFFSET + half),
        (CARD_X + CARD_W + REG_OFFSET + half, CARD_Y + CARD_H + REG_OFFSET + half),
    ]
    return max(math.hypot(x - cx, y - cy) for x, y in corners)


def coverage_for_round_mask(canvas: int, visible_fraction: float) -> float:
    """Largest coverage that keeps every drawn point inside a circular mask.

    `visible_fraction` is the diameter of the guaranteed-visible circle as a
    fraction of the layer the art is scaled into.
    """
    span, _, _ = hull()
    return visible_fraction / 2 * span / max_radius()


def mark_transform(canvas: int, coverage: float) -> str:
    """Centre and scale the mark so its longest side covers `coverage` of the canvas."""
    span, hx, hy = hull()
    scale = canvas * coverage / span
    return (
        f"translate({canvas / 2 - hx * scale:.2f} {canvas / 2 - hy * scale:.2f}) "
        f"scale({scale:.5f})"
    )


def mark_defs() -> str:
    return f"""    <linearGradient id="card" gradientUnits="userSpaceOnUse"
      x1="{CARD_X}" y1="{CARD_Y}" x2="{CARD_X + CARD_W}" y2="{CARD_Y + CARD_H}">
      <stop offset="0" stop-color="{CARD}"/>
      <stop offset="1" stop-color="{CARD_TINT}"/>
    </linearGradient>
    <linearGradient id="figure" gradientUnits="userSpaceOnUse"
      x1="{HEAD_CX - HEAD_RX}" y1="{CARD_Y}" x2="{HEAD_CX + HEAD_RX}" y2="{CARD_Y + CARD_H}">
      <stop offset="0" stop-color="{BLUE}"/>
      <stop offset="1" stop-color="{BLUE_DEEP}"/>
    </linearGradient>
    <clipPath id="cardClip">
      <rect x="{CARD_X}" y="{CARD_Y}" width="{CARD_W}" height="{CARD_H}" rx="{CARD_R}"/>
    </clipPath>"""


def registration_marks() -> str:
    """Four corner Ls, drawn outside the card."""
    left = CARD_X - REG_OFFSET
    right = CARD_X + CARD_W + REG_OFFSET
    top = CARD_Y - REG_OFFSET
    bottom = CARD_Y + CARD_H + REG_OFFSET
    corners = [
        (left, top, 1, 1),
        (right, top, -1, 1),
        (left, bottom, 1, -1),
        (right, bottom, -1, -1),
    ]
    out = []
    for x, y, sx, sy in corners:
        out.append(
            f'      <path d="M {x + sx * REG_ARM} {y} L {x} {y} '
            f'L {x} {y + sy * REG_ARM}" fill="none" stroke="{SKY}" '
            f'stroke-width="{REG_STROKE}" stroke-linecap="round" '
            f'stroke-linejoin="round"/>'
        )
    return "\n".join(out)


def mark() -> str:
    """The mark itself, in design-box coordinates."""
    # The eye-line rule runs in from both card edges and stops at the head, so
    # it reads as a measurement meeting the eyes rather than a line struck
    # through the face.
    dy = (EYE_Y - HEAD_CY) / HEAD_RY
    head_half = HEAD_RX * math.sqrt(max(0.0, 1 - dy * dy))
    gap = 18.0
    eye_left = HEAD_CX - head_half - gap
    eye_right = HEAD_CX + head_half + gap
    return f"""{registration_marks()}
      <rect x="{CARD_X}" y="{CARD_Y}" width="{CARD_W}" height="{CARD_H}"
            rx="{CARD_R}" fill="url(#card)"/>
      <g clip-path="url(#cardClip)">
        <ellipse cx="{HEAD_CX}" cy="{SHOULDER_CY}" rx="{SHOULDER_RX}" ry="{SHOULDER_RY}"
                 fill="url(#figure)"/>
        <ellipse cx="{HEAD_CX}" cy="{HEAD_CY}" rx="{HEAD_RX}" ry="{HEAD_RY}"
                 fill="url(#figure)"/>
        <path d="M {CARD_X} {EYE_Y} L {eye_left:.1f} {EYE_Y}
                 M {eye_right:.1f} {EYE_Y} L {CARD_X + CARD_W} {EYE_Y}"
              stroke="{BLUE}" stroke-opacity="{EYE_OPACITY}" stroke-width="{EYE_STROKE}"
              stroke-linecap="round"/>
      </g>"""


def plate(canvas: int, radius: float | None = None) -> str:
    r = f' rx="{radius}" ry="{radius}"' if radius else ""
    return f'  <rect width="{canvas}" height="{canvas}" fill="url(#plate)"{r}/>'


def plate_gradient(x2: int, y2: int) -> str:
    return f"""    <linearGradient id="plate" gradientUnits="userSpaceOnUse"
      x1="0" y1="0" x2="{x2}" y2="{y2}">
      <stop offset="0" stop-color="{INK_TOP}"/>
      <stop offset="0.55" stop-color="{INK}"/>
      <stop offset="1" stop-color="{INK_DEEP}"/>
    </linearGradient>"""


def icon_master(canvas: int = 1024) -> str:
    """Square, opaque, full-bleed. iOS rounds it itself; Android uses it as the
    legacy launcher icon and Play as the hi-res store icon.

    0.74 is the largest coverage that keeps the registration-mark elbows inside
    a full-bleed circular mask (`max_radius()` scales to 487 of the 512 radius),
    which is what a pre-adaptive-icon launcher can apply to this bitmap.
    """
    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="{canvas}" height="{canvas}" viewBox="0 0 {canvas} {canvas}">
  <title>Passport Photo Studio app icon</title>
  <defs>
{plate_gradient(canvas, canvas)}
{mark_defs()}
  </defs>
{plate(canvas)}
  <g transform="{mark_transform(canvas, 0.74)}">
{mark()}
  </g>
</svg>
"""


def transparent_mark(canvas: int, coverage: float, title: str) -> str:
    """The mark with no plate, for layers that supply their own background."""
    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="{canvas}" height="{canvas}" viewBox="0 0 {canvas} {canvas}">
  <title>{title}</title>
  <defs>
{mark_defs()}
  </defs>
  <g transform="{mark_transform(canvas, coverage)}">
{mark()}
  </g>
</svg>
"""


def plated_logo(canvas: int = 768) -> str:
    """The launch-screen logo: the icon, plate and all, on a transparent square.

    The mark's card is white, so it needs the navy plate to survive on the light
    launch background. Rounded rather than square so it reads as the app's icon
    rather than a photograph.
    """
    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="{canvas}" height="{canvas}" viewBox="0 0 {canvas} {canvas}">
  <title>Passport Photo Studio splash logo</title>
  <defs>
{plate_gradient(canvas, canvas)}
{mark_defs()}
  </defs>
{plate(canvas, canvas * 0.224)}
  <g transform="{mark_transform(canvas, 0.74)}">
{mark()}
  </g>
</svg>
"""


def feature_graphic(w: int = 1024, h: int = 500) -> str:
    """Google Play feature graphic. Mark left, name and promise right.

    Play crops this on some surfaces, so nothing load-bearing sits in the outer
    ~100px on either side.
    """
    span, hx, hy = hull()
    scale = 352 / span
    mx, my = 200 - hx * scale, 250 - hy * scale

    # A faint measuring rule along the bottom, echoing the registration marks.
    ticks = []
    for i, x in enumerate(range(64, w - 40, 34)):
        long = i % 4 == 0
        y0 = 468 if long else 476
        ticks.append(
            f'  <path d="M {x} {y0} L {x} 486" stroke="{SKY}" '
            f'stroke-opacity="{0.30 if long else 0.16}" stroke-width="3" '
            f'stroke-linecap="round"/>'
        )

    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">
  <title>Passport Photo Studio - Google Play feature graphic</title>
  <defs>
{plate_gradient(w, h)}
{mark_defs()}
  </defs>
  <rect width="{w}" height="{h}" fill="url(#plate)"/>
{chr(10).join(ticks)}
  <g transform="translate({mx:.2f} {my:.2f}) scale({scale:.5f})">
{mark()}
  </g>
  <g font-family="-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif">
    <text x="392" y="176" fill="{TEXT}" font-size="62" font-weight="800" letter-spacing="-1.6">Passport Photo</text>
    <text x="392" y="248" fill="{TEXT}" font-size="62" font-weight="800" letter-spacing="-1.6">Studio</text>
    <text x="392" y="308" fill="{SKY}" font-size="27" font-weight="600">Print-ready photos for 21 countries.</text>
    <g transform="translate(392 340)">
      <rect x="0" y="0" rx="21" ry="21" width="474" height="46" fill="{GREEN}" fill-opacity="0.14"
            stroke="{GREEN}" stroke-opacity="0.45"/>
      <text x="22" y="31" fill="{GREEN}" font-size="20" font-weight="700">No ads. Your photo never leaves your phone.</text>
    </g>
  </g>
</svg>
"""


def main() -> None:
    written = {
        "icon_master.svg": icon_master(),
        # Android adaptive foreground. flutter_launcher_icons wraps this in a
        # 16% inset, so the art lands in 68% of the 108 dp layer and only the
        # middle 66 dp of that layer is guaranteed visible — i.e. a circle
        # 66/(0.68 x 108) of the drawable wide. This mark has registration
        # marks out at its corners, so that limit binds hard: eyeballing a
        # coverage here clips them under a round launcher mask.
        "icon_foreground.svg": transparent_mark(
            1024,
            coverage_for_round_mask(1024, 66 / (0.68 * 108)),
            "Passport Photo Studio adaptive icon foreground",
        ),
        # Android 12+ splash icon: masked to a circle over the middle two thirds
        # of the drawable, with no inset, so it needs its own size.
        "splash_icon_android12.svg": transparent_mark(
            1152,
            coverage_for_round_mask(1152, 2 / 3),
            "Passport Photo Studio Android 12 splash icon",
        ),
        # flutter_native_splash treats the splash image as a 4x asset, so a 768
        # canvas lands the logo at a calm ~192 dp rather than filling the screen.
        "splash_logo.svg": plated_logo(),
        "feature_graphic.svg": feature_graphic(),
    }
    for name, svg in written.items():
        (HERE / name).write_text(svg)
        print(f"wrote {name}")


if __name__ == "__main__":
    main()
