#!/usr/bin/env bash
set -euo pipefail

# Wrapper script: find divs with both text-align:center and font-size:24px
# and wrap the entire <div...>...</div> with markdown bold markers **...**.
# It writes .bak backups for each file (original filename + .bak).

ROOT_DIR="$(dirname "$(dirname "$0")")"
LESSONS_DIR="$ROOT_DIR/course/lessons"

if [ ! -d "$LESSONS_DIR" ]; then
  echo "Lessons directory not found: $LESSONS_DIR" >&2
  exit 1
fi

shopt -s nullglob
for file in "$LESSONS_DIR"/*.md; do
  echo "Processing: $file"
  perl -0777 -i.bak -pe '
    s{(<div(?=[^>]*?text-align:\s*center)(?=[^>]*?font-size:\s*24px)[^>]*?>.*?</div>)}{**$1**}gsi;
  ' "$file"
done

echo "Done. Backup files with .bak extension created alongside originals."

exit 0
