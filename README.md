# r2-segregation

Reorganizes **all case PDFs** from the `legal-st` Cloudflare R2 bucket into a single
`PDF Cases/<State>/` tree, consolidating the scattered per-state sources.

This repo contains the mapping manifest and the resumable rclone runner so the job can be
executed (or continued) from any machine with rclone access to the bucket.

## What it does

For every row in `manifest.tsv`:

```
rclone copy r2:legal-st/<source> "r2:legal-st/PDF Cases/<State>/<origin>" \
  --include "*.pdf" --include "*.PDF"
```

- Copies **PDFs only** (scripts, logs, metadata, txt/html/json companions are skipped).
- Server-side copy: source and destination are the same R2 remote, so no data is downloaded.
- Destination keeps the original internal tree under an origin label, so duplicated sources
  (e.g. Florida from `fl`, `fl-legacy`, and `gitignored/legal-ai-scraper`) never collide.
- Idempotent: re-running skips sources already recorded in `copy-status.tsv` and rclone
  skips identical objects.

## Layout

| Path | Purpose |
|---|---|
| `manifest.tsv` | `target<TAB>source<TAB>expected_pdf_count` for all 54 source→state mappings |
| `run-copies.sh` | the runner (resumable; logs to `logs/` and `copy-master.log`) |
| `copy-status.tsv` | `target  source  expected  got  rc` for every completed source |
| `copy-master.log` | timestamped START/DONE/SKIP history |
| `summary.tsv` | per-state PDF totals derived from a full bucket listing |
| `validate.sh` | prints total size and per-state PDF counts for the result |

## Prerequisites on the target machine

1. **rclone** installed.
2. An rclone remote named `r2` for the R2 bucket (`Cloudflare` S3 provider):

   ```bash
   rclone config create r2 s3 \
     provider=Cloudflare \
     access_key_id=YOUR_ACCESS_KEY \
     secret_access_key=YOUR_SECRET \
     endpoint=https://<ACCOUNT_ID>.r2.cloudflarestorage.com \
     region=auto acl=private
   ```

   (or set `R2_REMOTE` to an existing remote+bucket, e.g. `export R2_REMOTE=other:legal-st`).
3. Verify access: `rclone lsf r2:legal-st/` should list the top-level prefixes.

## Run / resume

```bash
bash run-copies.sh
```

Run it detached for a long job, e.g.:

```bash
tmux new-session -d -s pdfcases "bash $(pwd)/run-copies.sh"
```

Monitor:

```bash
cat copy-status.tsv          # completed sources: expected vs got
cat .current                 # source currently being copied
tail -f copy-master.log
```

## Validate

```bash
rclone lsf "r2:legal-st/PDF Cases" -R --files-only | wc -l   # expect 1,314,918 once complete
rclone size "r2:legal-st/PDF Cases"                          # expect ~204 GiB
```

## Notes

- Total target: **1,314,918 PDFs, ~204 GB**, from 54 sources across 42 states plus
  `_Special` (DobbsData), `_Federal` (US Supreme Court), and `_Unknown` (unlabeled case PDFs).
- Duplicates across sources are intentionally **kept** (namespaced by origin).
- Adding a new prefix on R2 increases stored bytes by the copied amount.
