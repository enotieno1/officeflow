#!/usr/bin/env bash
# Vercel "Ignored Build Step" script.
# Exit 0 = SKIP the build. Exit 1 = BUILD.
#
# Allow both production and preview deployments. Preview builds are required for
# pull-request browser acceptance testing; do not silently skip non-main branches.

set -u

# Compare against the last successful deployment so multi-commit pushes do not
# accidentally skip earlier site changes. Fail open if the SHA is unavailable.
BASE_SHA="${VERCEL_GIT_PREVIOUS_SHA:-HEAD^}"
if ! git cat-file -e "${BASE_SHA}^{commit}" 2>/dev/null; then
  echo "Comparison commit ${BASE_SHA} not available; building."
  exit 1
fi

# If no served files changed, skip the build. Any uncertainty should build.
if git diff --quiet "$BASE_SHA" HEAD -- . \
  ':(exclude)docs' \
  ':(exclude)supabase' \
  ':(exclude)tests' \
  ':(exclude)*.md' \
  ':(exclude)tools/vercel-ignore-build.sh' \
  ':(exclude)tools/verify-live.sh'; then
  echo "Skipping build: only docs/migrations/tests/markdown changed since $BASE_SHA."
  exit 0
fi

echo "Served site files changed; building preview or production deployment."
exit 1
