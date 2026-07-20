#!/usr/bin/env bash
# Packages a `flutter build linux --release` bundle as a Linux AppImage.
# Uses ONLY appimagetool (MIT) — no other vendored packaging tool.
#
# Usage:
#   scripts/build_appimage.sh <version> [bundle-dir] [out-dir]
#
#   <version>    App version (e.g. 1.2.0), used in the output filename.
#   bundle-dir   The `flutter build linux --release` output.
#                Default: build/linux/x64/release/bundle
#   out-dir      Where to write the .AppImage. Default: dist
set -euo pipefail

version=${1:?"usage: $0 <version> [bundle-dir] [out-dir]"}
bundle_dir=${2:-build/linux/x64/release/bundle}
out_dir=${3:-dist}
binary_name=living_scroll
app_id=net.livingscroll.living_scroll

repo_root=$(git rev-parse --show-toplevel)
cd "$repo_root"

if [[ ! -x "$bundle_dir/$binary_name" ]]; then
  echo "error: $bundle_dir/$binary_name not found — run 'flutter build linux --release' first" >&2
  exit 1
fi

work_dir=$(mktemp -d)
trap 'rm -rf "$work_dir"' EXIT
app_dir="$work_dir/AppDir"

mkdir -p "$app_dir/usr/bin"
cp -r "$bundle_dir"/. "$app_dir/usr/bin/"
ln -s "usr/bin/$binary_name" "$app_dir/AppRun"

cp Assets/app_icon.png "$app_dir/$app_id.png"

cat > "$app_dir/$app_id.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=LivingScroll
Comment=Offline-first tabletop-RPG adventure authoring and play app
Exec=$binary_name
Icon=$app_id
Categories=Game;RolePlaying;
Terminal=false
EOF

appimagetool="$work_dir/appimagetool-x86_64.AppImage"
curl -fsSL -o "$appimagetool" \
  https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage
chmod +x "$appimagetool"

mkdir -p "$out_dir"
out_file="$out_dir/LivingScroll-$version-x86_64.AppImage"
# --appimage-extract-and-run: appimagetool is itself an AppImage, which needs
# FUSE to mount directly — this flag works on any runner regardless of
# whether FUSE/libfuse2 is installed. ARCH is explicit rather than guessed
# from the bundled binary (Flutter's release binary is stripped enough that
# appimagetool's ELF-arch sniffing isn't always reliable).
ARCH=x86_64 "$appimagetool" --appimage-extract-and-run "$app_dir" "$out_file"

echo "Built $out_file"
