#!/usr/bin/env bash
# Wraps the Flutter release bundle in an AppImage.
#   linux/packaging/build-appimage.sh <version> <output.AppImage>
# Run from the repo root after `flutter build linux --release`. Needs
# appimagetool on PATH. Like the tarball, the AppImage uses the system's GTK 3,
# libsecret and keyring rather than bundling them.
set -euo pipefail

version=$1
out=$2
bundle=build/linux/x64/release/bundle
appdir=$(mktemp -d)/PocketSense.AppDir
trap 'rm -rf "$(dirname "$appdir")"' EXIT

mkdir -p "$appdir"
cp -a "$bundle"/. "$appdir"/
cp linux/packaging/ace.software.pocketsense.desktop "$appdir"/
cp fastlane/metadata/android/en-US/images/icon.png "$appdir"/ace.software.pocketsense.png
ln -s ace.software.pocketsense.png "$appdir"/.DirIcon

cat > "$appdir"/AppRun <<'EOF'
#!/bin/sh
exec "$(dirname "$(readlink -f "$0")")/pocket_sense" "$@"
EOF
chmod +x "$appdir"/AppRun

# Extract-and-run: CI runners have no FUSE to mount appimagetool itself.
# -u embeds where updates live and writes "$out.zsync" beside it, so
# AppImageUpdate or Gear Lever can update in place; the app itself stays offline.
ARCH=x86_64 VERSION="$version" APPIMAGE_EXTRACT_AND_RUN=1 appimagetool --no-appstream \
  -u "gh-releases-zsync|software-ace|PocketSense|latest|PocketSense-*-linux-x64.AppImage.zsync" \
  "$appdir" "$out"
# zsyncmake (run by appimagetool without -o) writes the .zsync into the
# current folder, not beside $out; move it there so the release uploads it.
zsync=$(basename "$out").zsync
if [ -f "$zsync" ] && [ "$(realpath "$zsync")" != "$(realpath -m "$out.zsync")" ]; then mv "$zsync" "$out.zsync"; fi
