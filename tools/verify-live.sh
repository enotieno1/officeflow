#!/usr/bin/env bash
# Verifies that production serves the same bytes as this checkout.
# Usage: tools/verify-live.sh [base-url]
# Run from repository root after pulling the target branch.
set -u

BASE="${1:-https://office-sort.vercel.app}"
FILES=(
  "dashboard/control-tower.html"
  "dashboard/email-system.html"
  "dashboard/js/shared-navigation.js"
  "dashboard/js/ooes-auth.js"
  "dashboard/my-work.html"
  "dashboard/workflow.html"
  "dashboard/requestDetail.html"
)

echo "Local HEAD : $(git log -1 --format='%h %s (%cd)' --date=short)"
echo "Checking   : $BASE"
echo

fail=0
for f in "${FILES[@]}"; do
  if [ ! -f "$f" ]; then
    echo "SKIP  $f (not in checkout)"
    continue
  fi

  code=$(curl -s -o /tmp/officeflow-live-file -w '%{http_code}' -m 25 "$BASE/$f")
  if [ "$code" != "200" ]; then
    echo "FAIL  $f -> HTTP $code"
    fail=1
    continue
  fi

  live=$(sha256sum /tmp/officeflow-live-file | cut -d' ' -f1)
  loc=$(sha256sum "$f" | cut -d' ' -f1)
  if [ "$live" = "$loc" ]; then
    echo "OK    $f (matches repo)"
  else
    echo "STALE $f (live differs from repo HEAD)"
    fail=1
  fi
done

echo
if [ "$fail" = "0" ]; then
  echo "RESULT: production is serving the current repo files (for checked paths)."
else
  echo "RESULT: production is NOT fully in sync. Check Vercel > Deployments for failed"
  echo "        or rate-limited builds, then redeploy the latest commit."
fi
exit "$fail"
