#!/usr/bin/env bash
# Builds the downloadable game into export/:
#   BloomInProgress-windows.zip   (double-click BloomInProgress.exe)
#   BloomInProgress-linux.zip
#   BloomInProgress-macos.zip     (holds "Bloom In Progress.app")
# Usage: tools/build.sh [godot binary]
# Needs Godot's export templates for the same version installed
# (Editor > Manage Export Templates, or see .github/workflows/release.yml).
set -euo pipefail
GODOT="${1:-godot}"
cd "$(dirname "$0")/.."
mkdir -p export/windows export/linux export/macos
find export -type f -delete
"$GODOT" --headless --path . --import
"$GODOT" --headless --path . --export-release "Windows" export/windows/BloomInProgress.exe
"$GODOT" --headless --path . --export-release "Linux" export/linux/BloomInProgress.x86_64
"$GODOT" --headless --path . --export-release "macOS" export/macos/BloomInProgress.zip
chmod +x export/linux/BloomInProgress.x86_64
test -s export/windows/BloomInProgress.exe
test -s export/linux/BloomInProgress.x86_64
for platform in windows linux; do
	cp "packaging/How to play.txt" "export/$platform/"
	(cd "export/$platform" && zip -q -r "../BloomInProgress-$platform.zip" .)
done
# Godot zips the Mac app itself; add the how-to and give it its download name.
test -s export/macos/BloomInProgress.zip
mv export/macos/BloomInProgress.zip export/BloomInProgress-macos.zip
(cd packaging && zip -q ../export/BloomInProgress-macos.zip "How to play.txt")
ls -la export/*.zip
