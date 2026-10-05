#!/bin/bash
# Validate the PDF Cases tree: total objects/size and per-state PDF counts.
# Usage: bash validate.sh            (uses r2:legal-st)
#        R2_REMOTE=r2:legal-st bash validate.sh
set -u
REMOTE="${R2_REMOTE:-r2:legal-st}"
DEST="$REMOTE/PDF Cases"

echo "== TOTAL =="
rclone size "$DEST"

echo
echo "== PER STATE =="
rclone lsf "$DEST" --dirs-only | while IFS= read -r d; do
  n=$(rclone lsf "$DEST/$d" -R --files-only 2>/dev/null | wc -l)
  printf "%-28s %8d\n" "$d" "$n"
done
