# OfficeFlow Comprehensive Module Readiness Matrix

This matrix is the acceptance contract for OfficeFlow as a multi-tenant SaaS operating system. A module is not considered complete because a page, menu item, database table, or mock record exists. It is complete only when the authenticated end-to-end journey works with tenant isolation, department scope, auditability, useful failure states, and regression tests.

## Current evidence snapshot

Reviewed against the repository's current default branch and the connected production Supabase schema on 2026-10-20.

- Existing foundation: organization provisioning; six-role profile model; departments/organizational units; workflow definitions, versions, steps, requests and comments; task records; document records; HR/employee records; financial transactions; audit events; notifications; automation rules/runs; fraud-alert records; billing plan/subscription/payment-attempt/provider-event tables; reporting/control-tower functions.
- Existing screens found: Work Center, Workflow Builder, My Work, Task Management, Document Management, HR Management, Financial Management, Reports, Security & Audit, Fraud & Risk Alerts, Control Tower, Departments, Notifications and Automation Engine.
- Important gaps observed in code: Task Management still contains hard-coded example task cards and functions labelled “Task details coming soon”, “Edit task coming soon” and “Export coming soon”. Its create form uses selectors whose IDs do not match the save handler's expected IDs, so the handler can submit empty values. This module is not ready to call comprehensive.
- No dedicated calendar/scheduling page was found at the expected dashboard paths, and the public schema has no calendar/events table in the reviewed table inventory.
- An email outbox table and claim function exist, but this alone does not prove an email inbox/composer, provider delivery, retries, delivery status, templates, or organization-configured communications work end to end.
- No AI assistant/productivity service or model integration was verified in the reviewed schema/pages. AI capability must not be advertised as live until implemented, secured, and tested.
- Billing tables and IntaSend-related functions exist, but live provider credentials, successful hosted checkout, verified callbacks, subscription enforcement, and renewal/failure handling require separate end-to-end verification.
- HR and finance pages are substantial existing surfaces, but they still require a workflow-by-workflow functional audit, permission testing, and validation against real organization data before being labelled comprehensive.

## Definition of done for every module

- Real authenticated UI; no hard-coded demo data, fake success messages, or nonfunctional controls.
- All writes use validated inputs and the current authenticated organization; no client can select another tenant's organization ID to gain access.
- Row-level security and server-side authorization enforce organization and department boundaries independently of hidden UI.
- Clear loading, empty, success, validation, permission-denied, network-error and retry states.
- Audit history for sensitive changes; actor, timestamp, target, and outcome captured where appropriate.
- Search, filtering, sorting, pagination, and export where the module needs them.
- Mobile and keyboard accessibility; destructive actions require confirmation.
- Automated regression tests for the normal path, invalid input, cross-tenant access, wrong-role access, and service failures.
- Production secrets remain server-side. No private credentials or personal records in client code or logs.

## Required module acceptance criteria

### 1. Task and workflow management
- Create, view, edit, assign/reassign, comment on, prioritize, categorize, schedule, complete, reopen (with authorization), cancel, and archive tasks.
- Real status tabs and filters; due/overdue indicators; assignee and department queues; search; pagination; safe CSV export.
- Task details page/modal includes history, comments, attachments, related workflow/request, creator, assignee, timestamps, and due date.
- Workflow builder supports drafts, validation, versioning, publish/retire, step ordering, role/department approvers, segregation-of-duties rules, SLA timers, escalation and notifications.
- My Work reflects actual assigned tasks and approval steps; decisions update records atomically and are audited.
- Verify that no employee can view another department's work unless explicitly assigned or granted a documented role.

### 2. Document management
- Secure upload/download using private object storage and short-lived signed links; never public-bucket sensitive files.
- Folders/categories, metadata, tags, search, type/date/owner filters, preview where supported, version history, retention, archive, restore and authorized deletion.
- Access inheritance and overrides by organization/department/role; audit uploads, downloads, shares, version changes and deletion.
- Scan/import must store the actual file and metadata; OCR/extraction status and failure handling must be visible. A record without a retrievable private file is not a complete document.
- Test large files, invalid types, duplicate names, revoked access, and cross-tenant file URL attempts.

### 3. Human resources
- Employee lifecycle: onboarding, profile, department/job/manager, contracts and documents, status changes, offboarding and access revocation.
- Leave/absence requests, policy balances, approval chains, calendars, attendance where configured, performance/review records, training and HR case tracking.
- Confidential fields (salary, health, disciplinary and personal documents) restricted to specifically authorized HR/leadership roles; general managers see only approved aggregates.
- Employee self-service limited to own profile, own requests and authorized documents; department heads see only their allowed department scope.
- Payroll-related exports/calculations must have validated rules, change history and clear boundaries; do not claim statutory payroll compliance without Kenya-specific validation.

### 4. Finance and administration
- Finance: budgets, chart/categories, income and expenditure, invoices/bills, payment requests, approvals, vendors, purchase orders, reimbursements, assets/stock where enabled, reconciliations, period close and audit trail.
- Financial controls: maker-checker, approval thresholds, duplicate/round-number/split-payment flags, immutable transaction references, attachment evidence, reversal rather than silent deletion, and finance-role access.
- Reports: cash flow, budget vs actual, spend by department/category/vendor, commitments, ageing and exportable period-based statements.
- Administration: procurement/facilities/assets, office supplies, travel, maintenance, contracts, compliance deadlines and service requests with owner, SLA, status and evidence.
- Reconcile every displayed total against the underlying filtered records; define currency, period, timezone and treatment of cancelled/reversed items.
- This is operational workflow support, not a claim that OfficeFlow replaces a regulated accounting system without accounting controls and professional validation.

### 5. Email and communication
- Organization-branded transactional email for invitations, password/reset flows, task assignments, approvals, due/overdue notices, security events, billing and fraud alerts.
- Provider integration must use server-side secrets, verified delivery configuration, retry/backoff, idempotency, suppression/bounce handling, and delivery/error audit.
- In-app notifications support unread/read, deep links, preference controls and escalation.
- If internal messaging is offered, provide conversations, recipients, department/role visibility, attachments, search and retention rules; do not present email-outbox records as a full mailbox.
- Validate email delivery using a configured provider; no UI-only “sent” status.

### 6. Calendar and scheduling
- Organization calendar with personal/team/department views, event create/edit/cancel, recurring events, invitations, attendee response, reminders and conflict detection.
- Link events to tasks, leave, meetings, approvals and due dates; timezones and daylight-saving-safe storage.
- Permissions for private/personal events and leadership-only events; department calendars must not leak private HR details.
- Email/in-app reminders must be sent by a real scheduled backend job, with idempotency and retry.
- Provide list/week/month views, keyboard/mobile use, and tests for overlapping events, recurring edits and timezone boundaries.

### 7. Reports and insights
- Live data-backed metrics with documented definitions, date ranges, organization/department filters and role-aware aggregation.
- Task completion/ageing, SLA breaches, workflow bottlenecks, document activity, HR aggregates, finance summaries, administrative service levels and fraud case status.
- Drill-down to source records only where the user has permission; aggregation must not leak confidential HR/finance details.
- CSV/PDF export with applied filters, timestamp and data scope; export permission and audit.
- Verify totals against SQL fixtures and tests; no demo metrics or empty placeholder charts.

### 8. AI-assisted productivity
- Clearly scoped features: draft/rewrite/summarize communications, summarize permitted documents, extract document metadata, recommend task priority, explain workflow bottlenecks and produce report narratives.
- AI must use only records the current user can already access; server-side authorization before retrieval; no cross-tenant retrieval or private key in browser code.
- Show source links for grounded summaries, distinguish suggestions from verified facts, require human approval for external communications and sensitive decisions, and never autonomously approve payments/HR actions.
- Redact or minimize sensitive data; document provider retention/training settings, rate limits, costs, prompt-injection handling, logging policy and user opt-out.
- If model provider credentials or privacy configuration are absent, show the feature as unavailable/configuration required—not a simulated assistant.

### 9. Security and access management
- Organization isolation on every tenant table, private storage and server-side function; cross-tenant negative tests.
- Least-privilege roles and department/unit membership; leadership-wide views limited to explicit administrator/super-admin or separately authorized executive permissions.
- HR and finance access separately controlled; UI visibility is not authorization.
- Secure user invitations, account recovery, session handling, role changes, MFA policy where supported, audit logs, active sessions/revocation and joiner/mover/leaver controls.
- Security review of SECURITY DEFINER functions, views, storage policies, exposed GraphQL/Data API, leaked-password protection, rate limits and secrets.
- Run current security advisors and role-matrix regression tests; resolve findings based on impact, not by indiscriminately removing required grants.

## Release gates

1. Remove demo records and repair task create/detail/edit/export before declaring Task Management ready.
2. Complete module-by-module UI-to-database wiring and role/department negative tests.
3. Implement calendar storage and UI; implement actual email delivery; define the AI provider and server-side policy before enabling AI features.
4. Validate HR/Finance/Admin processes and reports using seeded non-production test tenants.
5. Complete live sign-up -> organization setup -> invite staff -> execute workflow -> view authorized reports -> checkout/payment verification -> subscription enforcement journey.
6. Pilot with one consenting organization, log defects, and only then label the service production-ready.

This matrix is an engineering acceptance specification and evidence log, not a statement that every listed capability is already implemented.
