#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Rasterise the SVG masters in this folder to the PNGs the Flutter tooling
# consumes. Uses headless Google Chrome, which is the only SVG rasteriser this
# machine is guaranteed to have.
#
#   ./render.sh
#
# Then, from the project root:
#   dart run flutter_launcher_icons
#   dart run flutter_native_splash:create
# ---------------------------------------------------------------------------
set -euo pipefail
cd "$(dirname "$0")"

CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
[ -x "$CHROME" ] || { echo "Google Chrome not found at $CHROME"; exit 1; }

shot() {  # shot <svg> <png> <width> <height> <bg>
  "$CHROME" --headless=new --disable-gpu --hide-scrollbars \
    --force-device-scale-factor=1 --window-size="$3,$4" \
    --default-background-color="$5" \
    --screenshot="$2" "file://$PWD/$1" >/dev/null 2>&1
  echo "rendered $2 (${3}x${4})"
}

TRANSPARENT=00000000

shot icon_master.svg           icon_master.png           1024 1024 "$TRANSPARENT"
shot icon_foreground.svg       icon_foreground.png       1024 1024 "$TRANSPARENT"
shot splash_icon_android12.svg splash_icon_android12.png 1152 1152 "$TRANSPARENT"
shot splash_logo.svg           splash_logo.png            768  768 "$TRANSPARENT"
shot feature_graphic.svg       feature_graphic.png       1024  500 "$TRANSPARENT"

# Chrome honours an SVG's intrinsic size and crops rather than scales, so every
# smaller square comes from the 1024 master via sips.

# Google Play's hi-res store icon: 512 square, 32-bit PNG, no alpha.
cp icon_master.png play_icon_512.png
sips -z 512 512 play_icon_512.png >/dev/null
echo "rendered play_icon_512.png (512x512)"

# Previews for docs, and for checking the mark still reads at launcher size.
for size in 256 48; do
  cp icon_master.png "icon_preview_${size}.png"
  sips -z "$size" "$size" "icon_preview_${size}.png" >/dev/null
  echo "rendered icon_preview_${size}.png (${size}x${size})"
done

echo "Done."
