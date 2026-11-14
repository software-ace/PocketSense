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
# appimage.github.io shows this file's screenshots instead of its own test's.
# Named .appdata.xml: appimagetool 1.9.1 looks for (and validates) only that name;
# the validator also wants the .desktop file it points to under usr/share/applications.
install -Dm644 linux/packaging/ace.software.pocketsense.desktop -t "$appdir"/usr/share/applications
install -Dm644 linux/packaging/ace.software.pocketsense.metainfo.xml \
  "$appdir"/usr/share/metainfo/ace.software.pocketsense.appdata.xml
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
ARCH=x86_64 VERSION="$version" APPIMAGE_EXTRACT_AND_RUN=1 appimagetool \
  -u "gh-releases-zsync|software-ace|PocketSense|latest|PocketSense-*-x86_64.AppImage.zsync" \
  "$appdir" "$out"
# zsyncmake (run by appimagetool without -o) writes the .zsync into the
# current folder, not beside $out; move it there so the release uploads it.
zsync=$(basename "$out").zsync
if [ -f "$zsync" ] && [ "$(realpath "$zsync")" != "$(realpath -m "$out.zsync")" ]; then mv "$zsync" "$out.zsync"; fi
# AppImages up to v2.5.0 were named …-linux-x64 and look for that .zsync.
# The same file works for them: its URL is relative, so it points at the
# new AppImage beside it. shortcut: drop once few run v2.5.0 or older.
cp "$out.zsync" "$(dirname "$out")/PocketSense-legacy-linux-x64.AppImage.zsync"
