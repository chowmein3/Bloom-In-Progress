#!/usr/bin/env bash
# Publishes the zips built by tools/build.sh to the repository's `downloads`
# branch, replacing what was there. The README's download links point at it:
#   https://github.com/<owner>/<repo>/raw/downloads/BloomInProgress-windows.zip
# Usage: tools/publish_downloads.sh   (after tools/build.sh; needs push access)
set -euo pipefail
cd "$(dirname "$0")/.."
test -s export/BloomInProgress-windows.zip
test -s export/BloomInProgress-linux.zip
test -s export/BloomInProgress-macos.zip
SOURCE=$(git rev-parse --short HEAD)
WORK=$(mktemp -d)
trap 'git worktree remove --force "$WORK" 2>/dev/null || true' EXIT
git worktree add -q --detach "$WORK"
cp export/BloomInProgress-windows.zip export/BloomInProgress-linux.zip export/BloomInProgress-macos.zip "$WORK/.."
(
	cd "$WORK"
	git checkout -q --orphan downloads-new
	git rm -rfq .
	mv ../BloomInProgress-windows.zip ../BloomInProgress-linux.zip ../BloomInProgress-macos.zip .
	printf '# Bloom In Progress downloads\n\nReady-to-play builds of the game. The source is on the `main` branch.\n\n- **Windows:** `BloomInProgress-windows.zip` - unzip, double-click `BloomInProgress.exe`.\n- **Mac:** `BloomInProgress-macos.zip` - unzip, then right-click the app and choose Open the first time.\n- **Linux:** `BloomInProgress-linux.zip`\n\nThis branch holds only the latest build and is replaced each time.\n' > README.md
	git add -A
	git -c user.name="${GIT_AUTHOR_NAME:-Bloom build}" -c user.email="${GIT_AUTHOR_EMAIL:-build@users.noreply.github.com}" \
		commit -q -m "Latest build of Bloom In Progress (from $SOURCE)"
	git push -f origin HEAD:downloads
)
git branch -D downloads-new >/dev/null 2>&1 || true
echo "published build of $SOURCE to the downloads branch"
