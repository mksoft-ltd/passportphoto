#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Render every store screenshot frame to a final PNG at exact store dimensions
# using headless Google Chrome. Output lands in out/<platform>/<slug>.png.
#
#   ./render.sh                 # every platform
#   ./render.sh ios69 android   # just these
#
# Platforms: ios69 (1320x2868) ios67 (1290x2796) android (1080x1920)
#
# Drop the raw captures into raw/<ios|android>/ first; without them the frames
# render a branded "capture missing" placeholder that names the screen and the
# state it has to be in, so the copy can be signed off before anything is shot.
# ---------------------------------------------------------------------------
set -euo pipefail
cd "$(dirname "$0")"

CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
[ -x "$CHROME" ] || { echo "Google Chrome not found at $CHROME"; exit 1; }

# Screen slugs, in store order. These match the names the screenshot harness
# (integration_test/screenshots_test.dart) writes, so raws drop straight in.
SCREENS=(01_result 02_sheet 03_home 04_picker 05_pro)
PLATFORMS=("${@:-ios69 ios67 android}")
# shellcheck disable=SC2206
PLATFORMS=(${PLATFORMS[@]})

size_for() {
  case "$1" in
    ios69)   echo "1320 2868" ;;
    ios67)   echo "1290 2796" ;;
    android) echo "1080 1920" ;;
    *) echo "unknown platform: $1" >&2; exit 1 ;;
  esac
}

for p in "${PLATFORMS[@]}"; do
  read -r W H <<<"$(size_for "$p")"
  mkdir -p "out/$p"
  for s in "${SCREENS[@]}"; do
    "$CHROME" --headless=new --disable-gpu --hide-scrollbars \
      --allow-file-access-from-files --force-device-scale-factor=1 \
      --window-size="${W},${H}" \
      --screenshot="out/$p/$s.png" \
      "file://$PWD/frame.html?screen=$s&platform=$p" >/dev/null 2>&1
    echo "rendered out/$p/$s.png (${W}x${H})"
  done
done

echo "Done. Upload out/ to App Store Connect / Play Console."
