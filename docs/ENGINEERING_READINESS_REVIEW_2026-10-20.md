# OfficeFlow Engineering Readiness Review — 2026-10-20

## Executive decision

**Not ready for general production launch.** OfficeFlow has a real Supabase-backed workflow foundation and meaningful database controls, but the complete customer journey and several advertised operational modules are not proven end to end. Treat this as a controlled pilot candidate only after the P0 security and onboarding gates below pass.

This review separates evidence from assumptions. A table, RPC, or page existing is not proof that a customer-facing function works.

## What was inspected

- GitHub repository structure, dashboard navigation, authentication wrapper, package-selection route, workflow UI/database helper, billing branch, feature verification matrix and product gap audit.
- Production Supabase schema/RLS and grants, billing schema, pricing rows, Edge Function inventory, security advisor and function definitions.
- Official IntaSend API docs for hosted checkout, M-Pesa STK push, webhook state changes and recurring card subscriptions.

## Verified in production during this review

- Existing workflow regression audit reports 17 SQL checks passed on 2026-10-19. These are database invariants, not full browser acceptance tests.
- Billing schema is present with RLS on plans, subscriptions, payment attempts and provider events.
- Published prices match the existing pricing page: Starter KES 10,000/month for 10 seats; Professional KES 40,000/month for 50 seats. Enterprise remains custom-priced and is not in self-service checkout.
- Billing database checks passed: RLS, no anonymous table grants, no client billing-state writes, no direct authenticated table reads after the read-RPC hardening, scoped overview RPC grants, service-role-only reconciliation RPC grants, and published pricing.
- Atomic payment reconciliation RPC exists and is executable only by service_role. It checks the stored API reference, invoice ID, amount and currency, handles duplicate events transactionally, and avoids downgrading an already-paid attempt on a stale event.
- IntaSend webhook Edge Function is deployed at version 3. It validates the configured webhook challenge and re-queries IntaSend's payment-status API before calling the reconciliation RPC.
- No subscription rows or payment-attempt rows were fabricated during this review.
- The legacy package-selection route is simplified on the billing implementation branch to rely on the Supabase session wrapper and redirect to the canonical billing page.

## Billing release status

**Foundation implemented; end-to-end billing not signed off.**

- The billing page, scoped billing read RPC, migrations, Playwright test specification and package-selection redirect are on draft PR #17 and are not yet part of the default branch.
- The deployed checkout Edge Function is still version 1; an attempt to deploy the hardened branch revision was blocked by the execution safety check. Do not assume the latest checkout reliability fix is live. The official checkout API returns a hosted checkout-session ID, which is distinct from the collection invoice ID; a separate `provider_checkout_id` column and corrected branch handling have been added, but that checkout code is not yet deployed.
- Merchant sandbox/live keys, webhook registration and actual provider callback delivery have not been verified in this review.
- No authenticated browser test or real sandbox payment was completed.
- Automatic recurring card subscriptions, M-Pesa renewal collection/scheduling, cancellation lifecycle, failed-renewal grace handling and plan entitlement enforcement remain unfinished. IntaSend has a separate recurring-card subscription API and subscription-event webhook; those are not integrated yet.
- The webhook RPC hardening is live in the production database and webhook v3 is deployed. Because the full checkout/browser path is unverified, do not turn on live billing or advertise automatic renewals.

## Product/module review

| Domain | Current assessment | Required proof or implementation |
|---|---|---|
| Sign-up, sign-in, password reset, session expiry | Partial | Browser-test fresh account, email confirmation behavior, profile provisioning, refresh, expiry, sign-out and reset. Consolidate old auth patterns and test every protected route. |
| Organization onboarding | Partial | Test a new organization end to end; first user becomes admin; verify a second organization cannot read or mutate the first organization's data. |
| Roles and tenant isolation | Database controls exist; full isolation tests not run | Run two-tenant tests for REST/RPC/direct URL access and sensitive HR/finance records. Review each RLS policy against the intended role/organization boundary. |
| Workflow builder and request lifecycle | Backend/RPC foundation exists; UI acceptance partial | Test create/edit/publish, immutable in-flight versions, submit, route, approve, reject, return, cancel, resubmit, role separation, audit events and SLA escalation. |
| SLA / escalation | Scheduler and SQL invariants exist | Execute a controlled overdue fixture and verify one escalation, notification and audit record, including retry behavior. |
| Automation | Schema/RPC foundation; production snapshot had zero rules/runs | Test each supported trigger/action, idempotency, failures, retry behavior, tenant scoping and run history. |
| HR | Partial | Employee CRUD and authorized access; test leave, onboarding, transfer and attendance workflows. Do not market as a full HRIS/payroll until those lifecycles work. |
| Finance | Incomplete | Current finance page redirects to a generic operational module; a separate accountant portal uses sample data. Implement persistent expense/invoice/budget/approval records and reconcile all totals. Do not claim a full accounting ledger or payment execution. |
| Procurement | Gap/unknown | Supplier register, quote comparison, purchase orders, goods receipt and approval controls need dedicated persistent lifecycle and tests. |
| Documents | Partial | Verify private Storage bucket, upload, download authorization, versioning, size/type limits and retention; current register is not proof of full document lifecycle. |
| Notifications and email | Partial / unverified | Verify event coverage, mark-read, duplicate prevention, outbox retries, actual delivery and bounce/failure handling. No successful sender delivery has been demonstrated. |
| Control Tower / reports | Partial | Reconcile every KPI to a documented query and test unit/role scope against fixture data. |
| Billing and entitlements | Foundation only | Finish checkout deployment, sandbox payments, renewal/cancel/failure paths and enforcement of seat/module limits. |
| External integrations / SSO | Blocked/unknown | Provider setup, secrets, error handling and successful external calls need proof. |
| Mobile/accessibility | Partial | Run viewport, keyboard, contrast and screen-reader checks across core journeys. |
| Production operations | Missing evidence | Add automated CI, error monitoring, backup/restore exercise, migration discipline, incident procedures and a real pilot. |

## Security advisor findings

The current Supabase advisor still reports:
- 15 public tables visible to authenticated users through GraphQL. This is not by itself proof of a data leak; grants and RLS must be assessed per object. Billing tables were removed from direct client table reads in this review.
- 14 SECURITY DEFINER RPC warnings. Several are public wrappers over private functions that contain organization/role checks, but every exposed function must be reviewed individually. Do not revoke grants blindly because the workflow UI depends on some RPCs.
- Leaked-password protection is flagged as not enabled.

The next security pass must verify that every exposed SECURITY DEFINER function has a fixed safe search_path, checks auth.uid(), role and organization as appropriate, and cannot accept another tenant's IDs. Test with separate authenticated identities, not just SQL catalog queries.

## Architecture and UX findings

- The dashboard's main navigation is more focused than the total repository: the repository contains many overlapping/legacy pages (for example separate spreadsheet, mail, drive and kanban-style pages). This makes the product feel like a bundle of tools rather than one coherent operations platform.
- Keep the primary navigation focused on Work Center, My Work, Workflows, People, Documents, Finance, Procurement, Reports/Control Tower, Notifications, Organization Settings and Billing. Retire or clearly label unfinished legacy modules rather than showing them as fully operational.
- Use one consistent shell, breadcrumb pattern, page title, primary action, loading state, empty state, permission-denied state and failure state. Avoid separate pages that silently redirect to generic placeholder modules.
- Make each enabled feature map to a real persistent operation and audit trail. Any feature without that proof should be marked preview/coming soon or removed from the production navigation.

## Delivery and test discipline

- The repository root currently has no standard package manifest or GitHub Actions workflow directory; the added Playwright spec is not yet executed by CI.
- Establish a repeatable test command and CI gate for lint/static checks, SQL regression checks against a disposable/staging database, browser E2E and accessibility checks.
- Use staging for destructive and cross-tenant tests. Do not create fake payment data or test real payments against production.
- Keep the billing work in draft PR #17 until code review and the sandbox payment/webhook matrix pass.

## Release gates

1. **P0 Security:** review all exposed functions/tables; fix any actual authorization defects; enable leaked-password protection if compatible; test cross-tenant boundaries.
2. **P1 Customer journey:** sign up -> confirm/sign in -> create organization -> invite users -> configure workflow -> submit/approve -> view audit/notifications.
3. **P1 Core modules:** prove workflow, HR, documents, tasks, notifications and reports with persistent test data and role-separated users.
4. **P1 Billing:** deploy the hardened checkout revision, configure IntaSend sandbox secrets/webhook, pass M-Pesa and card sandbox flows, duplicate/out-of-order webhook tests and failure cases.
5. **P1 Commercial lifecycle:** implement recurring card subscription events, M-Pesa renewal strategy, cancellation, grace period, dunning and server-enforced plan/seat entitlements.
6. **P2 Operations:** CI, monitoring, backup restore, documented incident response, performance tests and a real organization pilot.

## Links

- Draft billing PR: https://github.com/enotieno1/officeflow/pull/17
- SaaS launch gate: https://github.com/enotieno1/officeflow/issues/16
- IntaSend recurring subscriptions: https://developers.intasend.com/guides/subscriptions/
- IntaSend webhooks: https://developers.intasend.com/guides/webhooks/
