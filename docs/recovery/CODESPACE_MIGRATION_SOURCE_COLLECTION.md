# Codespace migration-source collection

Purpose: recover the original SQL source files and Git history needed to reconcile the production migration ledger with the repository. This procedure is **read-only** with respect to the Supabase project and does not apply, repair, reset, or deploy migrations.

## Important safeguards

- Run these commands only in the existing OfficeFlow Codespace at `/workspaces/officeflow`.
- Do not run `supabase db push`, `supabase migration repair`, `supabase db reset`, `supabase db pull`, or any deployment command during collection.
- Do not include `.env`, Supabase access tokens, service-role keys, database passwords, or other secrets in the archive.
- Do not copy SQL files into `supabase/migrations` merely because a filename is absent. Each source must be matched to the production migration ledger and reviewed first.

## Collection commands

Run this block in the Codespace terminal:

```bash
cd /workspaces/officeflow
set -euo pipefail

OUT="/tmp/officeflow-migration-recovery"
mkdir -p "$OUT"

# Record current workspace state without changing it.
git status --short --branch > "$OUT/git-status.txt"
git branch --all --verbose --no-abbrev > "$OUT/git-branches.txt"
git log --all --full-history --date=iso --format='%H %ad %s' --name-status -- supabase/migrations > "$OUT/migration-history.txt"

# Export the current migration directory, including untracked files.
if [ -d supabase/migrations ]; then
  tar -czf "$OUT/current-migrations.tgz" -C supabase migrations
fi

# Preserve all commits reachable from local branches/tags/remotes.
git bundle create "$OUT/officeflow-all-refs.bundle" --all

# Record checksums for integrity.
(
  cd "$OUT"
  sha256sum git-status.txt git-branches.txt migration-history.txt current-migrations.tgz officeflow-all-refs.bundle 2>/dev/null > SHA256SUMS || true
)

echo "Collection complete:"
ls -lh "$OUT"
```

The output directory is `/tmp/officeflow-migration-recovery`. Upload these files to this conversation:
- `current-migrations.tgz`
- `officeflow-all-refs.bundle`
- `migration-history.txt`
- `git-branches.txt`
- `git-status.txt`
- `SHA256SUMS` (if generated)

The Git bundle may be large. If upload size is a problem, start with `current-migrations.tgz`, `migration-history.txt`, and `git-branches.txt`; we can then target specific historical commits.

## Historical GitHub findings already identified

- The onboarding migration source exists on `main` as `supabase/migrations/20261018025834_self_service_organization_onboarding.sql`; the older commit used a different timestamp. This is a timestamp/name reconciliation candidate, not a missing source.
- Two migrations were explicitly removed by commits titled **“Remove unreviewed … migration from default branch”**:
  - `20261020143000_atomic_intasend_reconciliation.sql`
  - `20261020161000_task_assignment_trigger_fix.sql`
- Their deleted SQL is still visible in GitHub commit diffs, but the commit messages say they were unreviewed. They must be treated as **unapproved historical candidates**, not restored as active migrations and not assumed to have been applied in production.
- The historical commit for calendar work contains `20261020114716_calendar_events_module.sql`; the HR aggregate migration and performance/RLS migration also have historical commit records. These must be compared with the current ledger and source tree before any reconciliation.

## What happens after collection

1. Inventory all migration files across local branches and history.
2. Compare each file's exact SQL content and migration version with the production ledger.
3. Classify each production ledger entry as exact match, renamed/timestamp variant, source recoverable from history, or source still missing.
4. Keep unreviewed/unapplied candidates outside the executable migrations directory.
5. Update the recovery register and propose a separate review PR. No production changes are part of this work.
