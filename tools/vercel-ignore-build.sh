#!/usr/bin/env bash
# Vercel "Ignored Build Step" script.
# Exit 0 = SKIP the build. Exit 1 = BUILD.
#
# Always build pull-request/preview branches so acceptance tests can run.
# Production may skip commits that only change non-served files.

set -u

if [ "${VERCEL_GIT_COMMIT_REF:-main}" != "main" ]; then
  echo "Preview branch detected; building so pull-request changes can be tested."
  exit 1
fi

BASE_SHA="${VERCEL_GIT_PREVIOUS_SHA:-HEAD^}"
if ! git cat-file -e "${BASE_SHA}^{commit}" 2>/dev/null; then
  echo "Comparison commit ${BASE_SHA} not available; building."
  exit 1
fi

if git diff --quiet "$BASE_SHA" HEAD -- . \
  ':(exclude)docs' \
  ':(exclude)supabase' \
  ':(exclude)tests' \
  ':(exclude)*.md' \
  ':(exclude)tools/vercel-ignore-build.sh' \
  ':(exclude)tools/verify-live.sh'; then
  echo "Skipping production build: only docs/migrations/tests/markdown changed since $BASE_SHA."
  exit 0
fi

echo "Production site files changed; building."
exit 1
