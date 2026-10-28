# OfficeFlow Operational Audit — 28 October 2026

## Executive summary

**Status: not yet approved for unrestricted production rollout.** The connected Supabase project is active and the repository contains substantial product foundations, but the current evidence does not establish that every module passes end-to-end acceptance testing.

This audit separates (1) code present, (2) deployed backend/configuration, and (3) verified end-to-end behaviour. A table, page, Edge Function, successful preview build, or dashboard metric is not by itself proof of a working customer workflow.

## Scope and evidence

Reviewed on 2026-10-28:
- GitHub repository `enotieno1/officeflow`, default branch `main`.
- Open PR #47, `Expand OfficeFlow fraud detection across organisational levels`.
- Supabase project `oghowrilrhummzvrljdt`: public schema metadata, migrations, Edge Functions, security/performance advisors, database function definitions, table grants and RLS policies.
- Recent database logs.

The live browser UI could not be exhaustively exercised during this audit. User registration, email delivery, payment-provider callbacks, actual social publishing and payroll transfers are **not certified** by this report.

## Current backend snapshot

- Supabase project reports healthy.
- 46 public tables were returned by the schema listing; RLS was reported enabled on the listed public tables.
- Direct SQL returned 1 organisation, 6 profiles, 11 employee rows, 11 transaction rows, 0 fraud-alert rows, and 11 rows in the operational audit ledger (counts are a point-in-time snapshot, not verified customer counts).
- Table-listing metadata disagreed with direct SQL for employees and transactions. Reconcile the dashboard/report count source before relying on those figures.
- Recent logs show the scheduled `fn_escalate_overdue_steps()` job completing. This verifies that schedule only, not all automation.
- Production `scan_fraud_risks()` currently has three finance rules: duplicate transactions, possible split purchases, and high-value transaction review.
- PR #47 proposes two additional rules for sensitive audit-ledger changes and bursts of sensitive audit events. It remains unmerged and its migration has not been applied to production.

## Security findings

Supabase security advisor findings observed at audit time:

1. **GraphQL schema exposure — WARN, 34 objects.** Authenticated role has SELECT on tables/views visible through GraphQL. Visibility does not automatically prove cross-tenant row access; review each object's API exposure and RLS before changing grants.
2. **SECURITY DEFINER RPC exposure — WARN, 23 functions.** These may be intentional RPC endpoints, but each needs a function-by-function review of caller identity, organisation scoping, search_path, grants and allowed actions.
3. **Leaked-password protection disabled — WARN.** Enable through supported Auth settings and retest registration/password changes.
4. **RLS enabled without policies on social_media_connections and social_media_oauth_states — INFO.** Current table grants showed only postgres/service_role; this is consistent with service-role-only access, but keep it that way and test that client roles have no table privileges.
5. **Documents RLS policy overlap — remediated 28 October 2026.** `documents_insert_owner` and `documents_delete_owner_or_admin` overlapped with `documents_owner_or_admin` and did not apply its HR-sensitive-name restriction. Both overlapping policies were dropped from the connected production database. Verification confirms only `documents_owner_or_admin` remains on `public.documents`; it retains organisation scoping, owner/admin checks and HR-sensitive-name restrictions.
6. **Duplicate fraud-alert index — remediated 28 October 2026.** Dropped `fraud_alerts_org_fingerprint_uidx`; verification confirms the constraint-backed unique index `fraud_alerts_organization_id_fingerprint_key` remains.
7. Performance advisor: 33 unindexed foreign keys, 24 RLS policies with avoidable per-row auth-function evaluation, 49 unused-index candidates. Review incrementally; do not blindly delete indexes or mass-rewrite policies.

## Module readiness matrix

| Area | Evidence available | Acceptance work still required |
|---|---|---|
| HR | Tables and permission migrations exist | Create/update employee, leave approval, compensation changes, payroll periods, reports, role-denial tests |
| Finance/admin | Transactions, invoice and billing foundations exist | Expense-to-payment workflow, reconciliations, approval separation, report accuracy |
| Tasks/workflows | Workflow tables and scheduled overdue escalation exist | Submit/reject/resubmit/complete, escalation and notification end-to-end tests |
| Documents | Document table and policies exist | Real file persistence/download, versions, tenant isolation and HR document restriction tests |
| Email/communications | Notification and outbox foundations exist | Provider delivery, recipient correctness, retry/failure handling |
| Calendar | Calendar records/table exist | Create/update, invitation, reminders, time-zone and permission tests |
| AI | AI Edge Function deployed | Provider configuration, real response tests, data-permission checks and clear unavailable state |
| Reports | Data/report foundations exist | Reconcile each metric to source SQL; resolve employee/transaction count mismatch |
| Security/fraud | RLS, audit ledger and three production finance rules exist | Remediate advisors, test tenant isolation and add verified broader detection coverage |
| Signup/invitations | Onboarding migrations and invitation function exist | Fresh-org registration, confirmation, first admin, invite acceptance, password reset and idle expiry |
| Billing | Checkout/webhook functions and plans exist | Signature verification, idempotency, failed-payment handling, subscription lifecycle tests |
| Payroll payments | Payroll-related backend exists | Provider credentials/approval, reconciliation and safe sandbox tests; no real transfers during tests |
| Social Media Studio | OAuth function with state hashing and encrypted-token code exists | Provider credentials, callback, real authorised account connection, publish/readback and revoke tests |
| External integrations | Some integration foundations exist | Test each provider independently; do not label unconfigured integrations connected |

## Remediation plan

### P0 — Completed 28 October 2026
- Dropped the overlapping Documents INSERT/DELETE policies. Verified that only the stricter `documents_owner_or_admin` policy remains, preserving tenant, owner/admin and HR-sensitive-document restrictions.
- Dropped the redundant `fraud_alerts_org_fingerprint_uidx`; verified the constraint-backed unique index remains.
- Re-ran Supabase advisors. The document-policy overlap and duplicate-index findings no longer appear. Remaining warnings require separate review.

### P1 — Security review before broad rollout
- Review all 23 SECURITY DEFINER functions and the 34 GraphQL-visible objects. Revoke exposure only after confirming the application doesn't depend on it; avoid blanket grants changes.
- Enable leaked-password protection if available in the current plan.
- Verify social token/state tables remain service-role-only.
- Test organisation isolation for every role and every sensitive workflow.

### P1 — Fraud intelligence
- Test PR #47 in isolated staging before merging/deploying its migration.
- Seed controlled cases for all five rules; test negative cases, deduplication, organisation isolation and permission denial.
- Ensure scans are scheduled or triggered appropriately and alerts reach assigned reviewers before claiming continuous monitoring.

### P2 — Customer acceptance
- Execute a fresh-organisation onboarding test.
- Run linked workflows through HR, Finance, Tasks, Documents, Notifications and Reports.
- Verify billing, AI, email, calendar, social publishing and payroll provider flows only with sandbox/test credentials.
- Test desktop/mobile, slow network, expired sessions, error messages and recovery.

## Deployment decision

Do not claim the full product is production-certified until P0 and P1 items are remediated and the acceptance matrix passes. The live UI and external integrations were not exhaustively tested in this audit. A preview build is not equivalent to production verification.
