# OfficeFlow module gap audit — 20 October 2026

This audit is based on the current repository code and a read-only schema/count inspection of Supabase project `oghowrilrhummzvrljdt`. A table or page existing does not prove the feature is production-ready. The following items are release blockers until tested and closed.

## Confirmed from current code / schema

| Area | What exists | Gap to close before calling it complete |
|---|---|---|
| Dashboard/navigation | Dashboard has links to the core module pages on the feature branch. | This branch is not the deployed site until merged and deployment succeeds. |
| Tasks | Task page reads live `tasks` rows and has task operations in its UI. | Exercise create/edit/assign/status/due-date paths against RLS, including cross-user and cross-organization denial. |
| Workflows | Workflow definitions, versions, steps, requests, request steps and workflow RPCs exist. | End-to-end tests for submission, approvals, separation of duties, resubmission, cancellation, SLA escalation and notifications. |
| Documents | Document page reads live `documents` metadata and offers a browser-only scan/transcript flow. | No Storage bucket was returned by the current bucket inspection. The scan UI explicitly does not upload the scan; persistent secure file upload/download, version history and access controls are not complete. Do not enable uploads until a private bucket and tenant/department-aware Storage RLS policies are deployed and tested. |
| HR | Employee table and a substantial legacy HR page exist. | The HR route currently redirects to the generic workflow catalogue. Employee table was empty in the inspected database. Full employee lifecycle, leave, attendance, recruitment, payroll confidentiality and tests remain unverified. |
| Finance | Transaction table and a legacy finance page exist. | Finance route currently redirects to the generic workflow catalogue. Transactions table was empty in the inspected database. Accounting-grade ledger, chart of accounts, reconciliations, invoices, approval controls, payroll and auditability remain unverified. |
| Email/communication | `email_outbox` table exists; the legacy email route redirects to the generic Communication workflow catalogue. | Outbox was empty. No end-to-end provider delivery, bounce/failure handling, retry monitoring, mailbox UI or inbound email integration was verified. Do not present queued email as delivered email. |
| Calendar | Calendar UI reads and writes `calendar_events`; schema includes time zone, visibility, recurrence rule and status. | Calendar table was empty. Verify RLS, recurrence processing, invites/reminders, attendee responses, conflict detection and edit/cancel permissions. |
| Reports/insights | Reports page and audit data exist. | Verify all metrics are computed from authorized live records, filters/exports work, and employee-sensitive details are not exposed in management aggregates. |
| AI productivity | Legacy AI page redirects to the Control Tower. | No verified server-side AI request path was found in the page code inspected; the legacy page contains simulated response logic. Replace it with a secured server-side integration before advertising AI-generated results. |
| Security/access | Supabase Auth, profile roles, RLS, security/audit page and fraud-alert page exist. | Test role matrix and cross-tenant/cross-department allow/deny cases. UI hiding is not authorization. Fraud detection must have deployed detection rules/scheduler and audited review actions; an empty alert table does not prove detection is working. |
| SaaS onboarding/billing | Organizations and billing-related tables exist. | No subscription rows were present in the inspected schema counts. Verify sign-up, organization creation, invite flow, subscription checkout, payment webhooks, entitlements, renewal, cancellation and failed-payment handling. |

## Data snapshot (inspection only)

At inspection time, these operational tables were empty: `employees`, `transactions`, `tasks`, `documents`, `email_outbox`, `automation_runs`, `billing_subscriptions`, `billing_payment_attempts`, `billing_provider_events`, `fraud_alerts`, and `calendar_events`. This is a snapshot, not proof that the app cannot create records. Workflow-related tables and some audit/notification tables had rows.

## Release gate

Do not label OfficeFlow fully operational until:
1. The feature branch is reviewed, merged, and deployed.
2. Each module passes authenticated happy-path CRUD/processing tests.
3. Each module passes unauthorized, wrong-department, and wrong-organization negative tests.
4. Persistent file storage and email/AI providers are configured where required.
5. Scheduled jobs and provider webhooks are observed working, not just defined.
6. A real organization can register, configure departments and roles, operate daily workflows, receive alerts, and complete the chosen subscription/payment flow.
7. The live site is smoke-tested on mobile and desktop after deployment.

Security note: file storage must use a private bucket and least-privilege Storage RLS; a public bucket is not appropriate for HR, finance, contracts or internal organizational records. See the official Supabase guidance: https://supabase.com/docs/guides/storage/security/access-control
