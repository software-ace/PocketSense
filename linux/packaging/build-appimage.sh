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
ARCH=x86_64 VERSION="$version" APPIMAGE_EXTRACT_AND_RUN=1 appimagetool --no-appstream "$appdir" "$out"
