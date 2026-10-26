# Deployment and Migration Runbook

Last reviewed against production Supabase project `oghowrilrhummzvrljdt`: 2026-10-26. Verify live settings before relying on these notes.

## 1. Vercel build-rate-limit failures

Vercel deployment quotas can be exhausted by frequent pushes, especially on plans with daily deployment limits.

This repository configures `ignoreCommand` to run `tools/vercel-ignore-build.sh`. It skips non-`main` branches and skips a production build only when no served files changed since the last successful deployment (changes limited to `docs/`, `supabase/`, `tests/`, Markdown, and the two helper scripts). If the comparison commit cannot be resolved, it builds.

**Working habit:** batch related UI fixes into one commit. If a deployment quota is already exhausted, wait for the quota reset or change plan, then redeploy the latest commit from Vercel → Deployments. An ignore command does not increase the plan's quota.

## 2. Verify production against the repository

From the repository root:

```bash
git pull origin main
bash tools/verify-live.sh
```

The script defaults to `https://office-sort.vercel.app` and checks hashes for selected production files. `OK` means that checked file matches; `STALE` means the live bytes differ; `FAIL` means the URL did not return HTTP 200. This is a targeted check, not proof that every route or backend feature works.

## 3. Supabase migration history drift

The patch author reported that production contains 86 applied migrations while the repository contains 23. Confirm this against the linked project before changing migration history.

Before reconciling history:

```bash
npx supabase login
npx supabase link --project-ref oghowrilrhummzvrljdt
npx supabase migration list
```

Review the output and back up/record the production schema state. Use `npx supabase db pull` only after confirming the linked project is the intended production project and reviewing its effects. Commit any resulting migration-history changes for review.

**Until migration history is reconciled, do not run `supabase db push` against production.** The migration `20261004134000_production_auth_profile_hardening.sql` is removed in this change because the supplied patch states it was never applied and is superseded. Verify that statement against production migration history before any manual migration operation; never apply it to production.

## 4. Security advisor items reported on 2026-10-26

These statuses are reported by the supplied patch and must be rechecked in the Supabase dashboard before being treated as current:

| Advisory | Reported status / action |
| --- | --- |
| `authenticated_security_definer_function_executable` | Accepted for review; verify each exposed wrapper enforces caller role and organization. |
| `pg_graphql_authenticated_table_exposed` | Reported accepted temporarily because app does not use GraphQL and tables have RLS. Reassess exposure and disable only after approval and compatibility checks. |
| `auth_leaked_password_protection` | Reported open. Review Authentication → Policies / Password security and enable if available for the plan. |

## 5. Safe release checklist

- Confirm the target branch and review the full diff.
- Confirm the ignore-build script behaves correctly for both site changes and docs-only changes.
- Run shell syntax checks: `bash -n tools/vercel-ignore-build.sh tools/verify-live.sh`.
- Confirm Vercel's project setting honors `ignoreCommand` and the production branch is `main`.
- Do not apply database migrations or initiate production schema changes as part of a frontend deployment.
- After merge/deployment, run the live hash check and test critical login/signup flows separately.
