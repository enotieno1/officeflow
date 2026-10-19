# OfficeFlow Architecture & Module Map
**Inspected:** 2026-10-19  
**Repository:** `enotieno1/officeflow`  
**Production Supabase:** `oghowrilrhummzvrljdt`

## Current architecture observed

- **Frontend:** Static HTML, JavaScript, Tailwind CDN and shared CSS, hosted through Vercel configuration.
- **Client:** `supabase-js v2` initialized from `dashboard/js/config.js`.
- **Authentication:** `dashboard/js/ooes-auth.js` uses Supabase Auth, profile lookup and a legacy localStorage flag used by some pages.
- **Database:** PostgreSQL on Supabase; RLS on all public tables according to the current regression checks.
- **Workflow mutations:** SQL RPCs including `fn_submit_request`, `fn_decide_request_step`, `fn_cancel_request`, `fn_resubmit_request`, `fn_publish_workflow_version`.
- **Workflow entities:** `workflow_definitions`, `workflow_versions`, `workflow_steps`, `requests`, `request_steps`, `request_comments`, `audit_events`.
- **Automation:** `automation_rules`, `automation_runs`, private automation runner and `workflow_actions`; event/action coverage must be verified.
- **Notifications:** `notifications`, `fn_my_notifications`, `fn_mark_notification_read`; `email_outbox` exists, but a successful sender/delivery path was not verified.
- **Organization isolation:** `organizations`, `profiles.organization_id`, tenant identifiers on other public business tables, RLS and guarded provisioning RPC.
- **Management:** `fn_control_tower`, `fn_operational_intelligence`, pages `dashboard/control-tower.html` and `dashboard/index.html`.
- **Legacy business records:** `employees`, `tasks`, `documents`, `transactions`, `departments`.

## Current frontend map and observed caveats

| Area | Main files | Current observation |
|---|---|---|
| Authentication | `dashboard/auth.html`, `dashboard/js/ooes-auth.js` | Supabase Auth exists; localStorage session flag remains for compatibility. Audit all page guards. |
| Organization setup | `dashboard/organization-setup.html` | Calls guarded organization-creation RPC; end-to-end onboarding not yet browser-tested. |
| Work Center | `dashboard/workflow.html`, `dashboard/js/workflow-db.js` | Calls request RPCs; test lifecycle with separate users. |
| Request detail | `dashboard/requestDetail.html` | Reads My Work / request information; test direct URL access and tenant boundaries. |
| Workflow Builder | `dashboard/workflow-builder.html` | Creates/publishes workflow configuration; verify validation and version behavior. |
| Automation | `dashboard/automation.html` | UI for rule configuration; production had zero rules/runs at audit snapshot. |
| Notifications | `dashboard/notifications.html` | Uses notification RPCs. Email delivery is separate and unverified. |
| Control Tower | `dashboard/control-tower.html`, `dashboard/index.html` | Calls database reporting RPCs; reconcile all metrics against SQL fixtures. |
| Documents | `dashboard/document-management.html` | Read-only register view. Storage lifecycle not verified. |
| Finance | `dashboard/financial-management.html`; `accountant-portal/server.py` | Finance page redirects to `operational-module.html?category=Finance`. The separate Python accountant portal returns hard-coded sample data; fake success responses for non-persistent invoice/expense/bill-payment actions were removed in PR #7. No real ledger/payment service is established. |
| Tasks | `dashboard/tasks-management.html` | Legacy page includes localStorage gate; live CRUD lifecycle not proven. |
| Packages | `dashboard/package-selection.html`, `dashboard/pricing.html`, `dashboard/packages.html` | UI exists; package selection has a localStorage-only guard. No subscription/payment tables found. The inspected baseline simulated successful payment and logged card/CVV-bearing data; remediation PR #6 disables checkout and removes credential collection. |

## Intended integrated flow

1. A user authenticates through Supabase Auth.
2. A guarded onboarding path assigns the user to exactly one organization and an appropriate role.
3. The organization configures departments/units, users and workflow definitions.
4. A user submits a workflow request through a guarded RPC.
5. The database creates request steps against a published workflow version and applies tenant/role rules.
6. The current approver acts through a guarded RPC; comments, decisions and audit events are recorded.
7. Automation can react to supported workflow events and create permitted actions such as notifications, tasks or email-outbox entries.
8. A background worker must claim and send outbox emails; the existence of the outbox is not delivery.
9. Control Tower queries summarize organization-scoped operations.
10. Subscription entitlements must be checked by a provider-backed billing layer before paid features are enforced.

Steps 1–8 have varying degrees of implementation evidence; end-to-end integration is not yet established. Step 10 is a missing capability in the inspected public schema.

## Target architecture principles

- Keep workflow state transitions in guarded database functions.
- Keep the six-role model stable and enforce authorization in the database, not only the UI.
- Tenant-scope every business record and test cross-tenant access using distinct authenticated users.
- Keep modules as domain workflows that share identity, tasking, notifications, audit and reporting.
- Prefer explicit typed actions over arbitrary SQL or user-provided scripts.
- Make automation idempotent and observable with run status, error information, bounded retry and duplicate protection.
- Store files in a storage service with tenant-aware policies; database metadata alone is not document storage.
- Treat billing as an auditable state machine driven by verified provider webhooks, not a front-end button.
- Separate provider configuration from code and never expose service-role credentials to the browser.
