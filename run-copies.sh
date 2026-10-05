#!/bin/bash
# Copy all case PDFs from legal-st sources into legal-st/PDF Cases/<State>/<origin>/
# Idempotent and resumable: re-running skips sources already recorded in copy-status.tsv.
#
# Requirements:
#   - rclone configured with an S3-compatible remote named "r2" pointing at the R2 bucket.
#   - Run from anywhere; paths below are relative to this script's directory.
set -u

BASE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REMOTE="${R2_REMOTE:-r2:legal-st}"
DEST="$REMOTE/PDF Cases"
MANIFEST="$BASE/manifest.tsv"
MASTER="$BASE/copy-master.log"
STATUS="$BASE/copy-status.tsv"
mkdir -p "$BASE/logs"
touch "$STATUS"

echo "[$(date)] ===== RUN START =====" >> "$MASTER"

while IFS='|' read -r target source expected; do
  [ -z "$target" ] && continue
  case "$target" in \#*) continue ;; esac

  key=$(printf '%s\t%s\t' "$target" "$source")
  if grep -qF "$key" "$STATUS" 2>/dev/null; then
    echo "[$(date)] SKIP  $target  <-  $source (already recorded)" >> "$MASTER"
    continue
  fi

  safe=$(printf '%s' "$target" | tr ' /' '__')
  log="$BASE/logs/${safe}.log"
  echo "[$(date)] START $target  <-  $source  (expect $expected)" >> "$MASTER"
  printf '%s\t%s\n' "$target" "$source" > "$BASE/.current"

  rclone copy "$REMOTE/$source" "$DEST/$target" \
    --include "*.pdf" --include "*.PDF" \
    --transfers 64 --checkers 32 \
    --retries 5 --low-level-retries 10 \
    --stats 60s --stats-one-line --stats-file-name-length 0 \
    --log-file "$log" --log-level INFO
  rc=$?

  got=$(rclone lsf "$DEST/$target" -R --files-only 2>/dev/null | wc -l)
  printf '%s\t%s\t%s\t%s\t%s\n' "$target" "$source" "$expected" "$got" "$rc" >> "$STATUS"
  echo "[$(date)] DONE  $target  rc=$rc  expected=$expected  got=$got" >> "$MASTER"
done < "$MANIFEST"

echo "[$(date)] ===== RUN COMPLETE =====" >> "$MASTER"
