#!/usr/bin/env bash
# Regenerates Assets/app_icon.png and Assets/app_icon_foreground.png from the
# single vector source of truth, Assets/icon-hires.svg, then re-runs
# flutter_launcher_icons so every platform icon it covers (Android, iOS,
# macOS, Windows, web) is rebuilt from the same artwork. This closes a real
# drift that happened before this script existed: a tweak to the SVG was
# committed without re-exporting the PNGs it was supposed to feed, so the
# shipped icon quietly fell out of sync with its own source art.
#
# Assets/icon-hires.svg is a plain, SHARP-CORNERED full-bleed square (an
# Inkscape export, no <rect rx=...> rounding) — every platform normally
# applies its OWN icon-shape mask (Android's adaptive-icon system, iOS's
# automatic corner rounding), so a raw square is the correct input for
# flutter_launcher_icons. The one consumer that does NOT mask automatically
# is Linux: the window icon (linux/runner/my_application.cc) and the
# AppImage icon (scripts/build_appimage.sh) both use Assets/app_icon.png
# verbatim, unmasked. To keep the already-shipped rounded-square look on
# Linux, this script applies a rounded-rect alpha mask (radius ~10.4% of the
# icon size — measured from the previously committed artwork) when producing
# Assets/app_icon.png itself. If you'd rather ship the raw sharp-cornered
# square everywhere, drop the mask step below.
#
# The foreground layer replicates Android's adaptive-icon convention: the
# same masked artwork scaled down and centered on a transparent canvas — the
# previously committed foreground trimmed to exactly 716x716 within a
# 1024x1024 canvas (offset 154,154), i.e. 70%, reproduced here as-is.
#
# Run this whenever Assets/icon-hires.svg changes, then commit the
# regenerated PNGs (and whatever flutter_launcher_icons rewrote elsewhere)
# together with it. Requires ImageMagick (`magick`) built with SVG/librsvg
# support, and — unless --skip-launcher-icons — the Dart/Flutter toolchain.
#
# Usage: scripts/generate_app_icons.sh [--skip-launcher-icons]
set -euo pipefail

repo_root=$(git rev-parse --show-toplevel)
cd "$repo_root"

svg_src="Assets/icon-hires.svg"
app_icon="Assets/app_icon.png"
app_icon_fg="Assets/app_icon_foreground.png"
size=1024
corner_radius=106 # ~10.4% of $size — matches the previously shipped artwork
fg_size=716        # 70% of $size — matches the previously shipped foreground

if [[ ! -f "$svg_src" ]]; then
  echo "error: $svg_src not found" >&2
  exit 1
fi
if ! command -v magick >/dev/null 2>&1; then
  echo "error: ImageMagick ('magick') not found (with SVG/librsvg support)." >&2
  exit 1
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

echo "==> Rendering ${size}x${size} from $svg_src"
magick -background none "$svg_src" -resize "${size}x${size}" "$tmp/raw.png"

echo "==> Masking to a rounded square (radius ${corner_radius}px) -> $app_icon"
magick -size "${size}x${size}" xc:none -fill white \
  -draw "roundRectangle 0,0 $((size - 1)),$((size - 1)) $corner_radius,$corner_radius" \
  "$tmp/mask.png"
magick "$tmp/raw.png" "$tmp/mask.png" -compose DstIn -composite "$app_icon"

echo "==> Rendering foreground (glyph at ${fg_size}px, transparent ${size}x${size} canvas) -> $app_icon_fg"
magick -size "${size}x${size}" xc:none \
  \( "$app_icon" -resize "${fg_size}x${fg_size}" \) \
  -gravity center -compose over -composite "$app_icon_fg"

if [[ "${1:-}" != "--skip-launcher-icons" ]]; then
  echo "==> Regenerating per-platform icons (dart run flutter_launcher_icons)"
  dart run flutter_launcher_icons
fi

echo "Done — review the diff (git status / git diff) and commit the regenerated icons."
