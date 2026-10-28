-- Narrow security remediation from the OfficeFlow operational audit (2026-10-28).
-- The all-command policy already enforces organisation ownership and the HR-sensitive
-- document restriction. The two overlapping permissive policies do not apply that
-- restriction, so removing them prevents PostgreSQL's permissive-policy OR semantics
-- from bypassing the stricter rule.
begin;

drop policy if exists documents_insert_owner on public.documents;
drop policy if exists documents_delete_owner_or_admin on public.documents;

-- Keep the constraint-backed unique index used to enforce idempotent alert fingerprints.
-- This separate index has the same key and is not owned by a constraint.
drop index if exists public.fraud_alerts_org_fingerprint_uidx;

commit;
