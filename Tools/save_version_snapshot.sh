#!/bin/zsh
set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: zsh Tools/save_version_snapshot.sh <version> [label]"
  exit 1
fi

VERSION="$1"
LABEL="${2:-snapshot}"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SNAPSHOT_DIR="$ROOT_DIR/Versions/_snapshots"
TIMESTAMP="$(date +%Y-%m-%d_%H-%M-%S)"
ARCHIVE_NAME="MazeDash_v${VERSION}_${LABEL}_${TIMESTAMP}.tar.gz"
ARCHIVE_PATH="$SNAPSHOT_DIR/$ARCHIVE_NAME"

mkdir -p "$SNAPSHOT_DIR"

tar \
  --exclude=".git" \
  --exclude=".release" \
  --exclude=".audit" \
  --exclude=".audit-dd" \
  --exclude=".audit-release-dd" \
  --exclude=".codex-dd" \
  --exclude=".preflight-archive" \
  --exclude=".preflight-release" \
  --exclude="Versions/_snapshots" \
  --exclude="AppStoreScreenshots" \
  --exclude="MazeDash.xcodeproj.pre-rebuild-backup" \
  -czf "$ARCHIVE_PATH" \
  -C "$ROOT_DIR" .

echo "Saved snapshot:"
echo "$ARCHIVE_PATH"
