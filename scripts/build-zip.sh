#!/usr/bin/env bash
# Builds dist/fundraise-with-claude.zip for uploading to claude.ai (Customize -> Skills -> Upload a skill).
#
# claude.ai wants the skill FOLDER at the top of the zip, named like the skill:
#   fundraise-with-claude.zip
#   └── fundraise/
#       ├── SKILL.md
#       ├── prompts/...
#       └── deck/...
# A SKILL.md sitting at the root of the zip is not recognised.
#
# Size: Anthropic does not publish an exact upload limit for skill zips. We keep it small on purpose:
# a warning above WARN_MB and a hard stop above MAX_MB (override with env vars if the limit is confirmed).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILL_NAME="fundraise"
SRC="$ROOT/plugins/fundraise/skills/$SKILL_NAME"
DIST="$ROOT/dist"
OUT="$DIST/fundraise-with-claude.zip"
WARN_MB="${WARN_MB:-5}"
MAX_MB="${MAX_MB:-8}"

fail() { echo "build-zip: FAIL: $*" >&2; exit 1; }

command -v zip >/dev/null || fail "the 'zip' command is not installed"
command -v unzip >/dev/null || fail "the 'unzip' command is not installed"
[ -f "$SRC/SKILL.md" ] || fail "missing $SRC/SKILL.md"
head -n 1 "$SRC/SKILL.md" | grep -qx -- '---' || fail "SKILL.md must start with '---' frontmatter"
grep -qx "name: $SKILL_NAME" "$SRC/SKILL.md" || fail "SKILL.md frontmatter must say 'name: $SKILL_NAME' (the folder name)"

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
mkdir -p "$STAGE/$SKILL_NAME"
# Copy the skill folder, leaving out OS clutter and anything secret-looking.
rsync -a \
  --exclude '.DS_Store' --exclude 'Thumbs.db' --exclude '__MACOSX' --exclude 'node_modules' \
  --exclude '.env' --exclude '.env.*' --exclude '*.pem' --exclude '*.key' \
  "$SRC/" "$STAGE/$SKILL_NAME/"

mkdir -p "$DIST"
rm -f "$OUT"
( cd "$STAGE" && zip -q -r -X "$OUT" "$SKILL_NAME" )

# Verify the layout.
LIST="$(unzip -Z1 "$OUT")"
echo "$LIST" | grep -qx "$SKILL_NAME/SKILL.md" || fail "zip does not contain $SKILL_NAME/SKILL.md"
if echo "$LIST" | grep -v "^$SKILL_NAME/" | grep -q .; then
  fail "zip has entries outside $SKILL_NAME/: $(echo "$LIST" | grep -v "^$SKILL_NAME/" | head -3 | tr '\n' ' ')"
fi

BYTES="$(wc -c < "$OUT" | tr -d ' ')"
MB="$(awk -v b="$BYTES" 'BEGIN { printf "%.2f", b / 1048576 }')"
FILES="$(echo "$LIST" | grep -vc '/$' || true)"
awk -v b="$BYTES" -v m="$MAX_MB" 'BEGIN { exit !(b > m * 1048576) }' && fail "zip is ${MB} MB, over the ${MAX_MB} MB cap. Shrink the preview images."
awk -v b="$BYTES" -v w="$WARN_MB" 'BEGIN { exit !(b > w * 1048576) }' && echo "build-zip: WARNING: zip is ${MB} MB (over ${WARN_MB} MB). Consider smaller previews."

echo "build-zip: OK  $OUT  (${MB} MB, ${FILES} files, top folder: $SKILL_NAME/)"
