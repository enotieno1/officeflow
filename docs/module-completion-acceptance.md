# OfficeFlow module completion and release acceptance

This checklist is the release gate for the nine core OfficeFlow modules. A module is not "complete" merely because a link, page, database table, or demonstration card exists.

## Release rule

Each checklist item must be demonstrated in the deployed application with a real authenticated account and real organization data. Test at minimum as employee, manager, department administrator, organization administrator, auditor, and super administrator. Test a second organization to prove tenant isolation. Never use invented sample values to imply live AI, financial, or fraud analysis.

## 1. Task and workflow management
- [ ] Create, view, edit, assign, prioritize, categorize, comment on, and close tasks.
- [ ] Due dates, overdue indicators, filters, search, and task history work.
- [ ] Workflow builder supports versioning, validation, publish/unpublish, required fields, approver routing, decisions, resubmission, cancellation, SLA deadlines and escalation.
- [ ] Submitter and approver can follow request history and receive notifications.
- [ ] Verify tasks are scoped by organization and access rules; use `tasks`, `workflow_definitions`, `workflow_versions`, `workflow_steps`, `requests`, `request_steps`, `request_comments`, and `audit_events`.

## 2. Document management
- [ ] Upload and download files using private object storage; never treat a user-provided URL as a trusted file.
- [ ] Folder/category, search, metadata, preview, replace/new version, archive/restore, retention and audit history.
- [ ] File size/type validation, malware-scanning integration or documented safe-upload controls, and signed download URLs.
- [ ] Permissions follow organization, unit and document sensitivity.
- [ ] Verify UI and storage policies; the `documents` table alone is not a document management system.

## 3. Human resources
- [ ] Employee profiles and lifecycle: onboarding, changes, transfers, offboarding, employment status and employee documents.
- [ ] Leave requests, balances, approvals, holidays and absence history.
- [ ] Attendance/working time only where the organization configures it; recruitment and performance reviews if enabled.
- [ ] Sensitive fields (salary, identity and personnel records) restricted to authorized HR/leadership roles.
- [ ] Use `employees` only after confirming the full lifecycle model and privacy policies; do not expose salary to ordinary employees.

## 4. Finance and administration
- [ ] Chart of accounts, ledger/journal entries, period close, bank/cash accounts, reconciliations, budgets, cost centres and financial statements.
- [ ] Payables/receivables, invoice and expense lifecycle, purchase requests/orders, supplier records, approvals and attachments.
- [ ] Currency, tax configuration, immutable posted entries, reversal/correction trail and export controls.
- [ ] Role separation for creator, approver and payer; prevent self-approval where policy requires.
- [ ] Existing `transactions` records are not a substitute for a balanced accounting ledger. Do not claim accounting-grade functionality until ledger invariants and reconciliation tests pass.

## 5. Email and communication
- [ ] Internal announcements/messages and notification preferences with read/unread state.
- [ ] Transactional email uses a configured provider, verified sender/domain, retries, idempotency, delivery/bounce handling and failure visibility.
- [ ] Email delivery status is distinct from an item merely being queued in `email_outbox`.
- [ ] Enforce recipient authorization and do not expose other users' messages or notification payloads.

## 6. Calendar and scheduling
- [ ] Create, edit, cancel and view events; timezone-aware start/end validation; calendar/list views.
- [ ] Recurrence, invitations/attendees, visibility, reminders, conflict detection and permissions.
- [ ] `calendar_events` must be tested for cross-unit visibility and organization isolation.
- [ ] Integration with external calendars is labelled unavailable until OAuth, sync and conflict handling are implemented and tested.

## 7. Reports and insights
- [ ] Filters by date, unit, workflow, status and authorized scope.
- [ ] Metrics derive from live database queries and define numerator, denominator, timezone and refresh time.
- [ ] CSV/PDF export respects the same permissions as the screen.
- [ ] Empty/error states are explicit; no hard-coded or cross-tenant figures.
- [ ] Reconcile every metric against a read-only SQL query and test unauthorized scopes.

## 8. AI-assisted productivity
- [ ] AI provider/model, credentials, budget, timeout, logging, data-retention and failure behaviour are configured server-side.
- [ ] AI operates only on records the current user is authorized to access; redact sensitive data where appropriate.
- [ ] Clearly label generated content, show sources for data-grounded answers, and require confirmation before sending messages or making changes.
- [ ] Never present hard-coded sample answers as live AI, nor AI-generated suspicion as confirmed fraud.
- [ ] Evaluate prompt injection, data leakage, incorrect summaries and graceful provider outage.

## 9. Security and access management
- [ ] Use one supported Supabase Auth session flow consistently; remove reliance on a browser-only `ooesSession` flag as proof of identity.
- [ ] RLS enabled and correct grants/policies on every exposed table; test allowed and denied operations.
- [ ] Organization isolation, department/unit scope, role permissions, server-side authorization and least privilege.
- [ ] Only explicitly authorized organization administrators and top leadership can access organization-wide control-tower, audit, financial and fraud views.
- [ ] Audit privileged actions; protect secrets; never expose service-role keys in browser code.
- [ ] Test logout, expired sessions, password reset, user deactivation, role changes and direct-URL access.

## Cross-module end-to-end tests
- [ ] Employee submits a request -> assigned approver decides -> SLA/notification updates -> audit trail records every transition.
- [ ] HR leave request affects only the authorized leave workflow and calendar.
- [ ] Purchase/expense request -> approval separation -> finance record -> report totals reconcile.
- [ ] Document attachment remains private and access follows the parent record's permissions.
- [ ] Fraud rule produces a reviewable alert with reproducible evidence, false-positive handling and resolution audit trail.
- [ ] Every direct URL, API call, export and storage object enforces the same permissions as the UI.
- [ ] Deployment smoke tests pass on desktop and mobile; production release is blocked on any critical security failure.

## Current implementation caution

Repository pages and tables have been found for several areas, but their existence is not proof that the above behaviours work. In particular, legacy module pages may route to the shared workflow interface. Mark each item complete only after implementation and a recorded test result.
