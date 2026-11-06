# OfficeFlow Africa Readiness: Implementation Plan

**Status:** Engineering plan; not a claim that external integrations are active  
**Scope:** Kenya-first, multi-country architecture  
**Owner:** OfficeFlow product/engineering  
**Reviewed:** 2026-10-26

## Executive decision

Treat these capabilities as shared platform rails, not nine unrelated features. Implement in this order:

1. Tenant-safe audit evidence and import preview/validation.
2. Compliance obligations, reminders and exportable statutory workpapers.
3. Optional field-location evidence for designated task types.
4. Offline-first / low-bandwidth sync with user-controlled immediate sync.
5. Telecom zero-rating and local-agent network as external commercial programmes.

Do not describe a capability as live until it has a production backend, authorization tests, observability, and end-to-end verification. No provider or regulator partnership is implied by this plan.

## 1. Zero-rating and low-bandwidth operation

### Product work we control

- Add a network-conscious client policy: cache static assets, compress payloads, paginate large lists, avoid polling when a tab is hidden, and use exponential backoff with jitter.
- Queue safe, idempotent writes while offline and show each item as **Pending sync**, **Synced**, or **Needs attention**. Never show a queued write as saved to the server.
- Provide a visible **Sync now** action and last successful sync time.
- Queue telemetry and non-urgent uploads for a configurable low-cost window only when the customer opts in. Do not delay approvals, security events, payroll controls, or time-sensitive alerts.
- Use server timestamps and idempotency keys to avoid duplicate transactions after retries. Resolve conflicts explicitly; never silently overwrite financial or HR records.
- Keep offline storage minimal and avoid caching sensitive payroll, identity, or financial payloads by default.

### External dependency: telco zero-rating

Zero-rating is a commercial/network configuration, not a client-side setting. Start a partnership discovery track with Safaricom and, where relevant, regional operators. Prepare: exact production domains/subdomains, traffic classes, TLS/CDN architecture, expected volumes, data-protection controls, support SLA, commercial model, and abuse prevention. Ask each operator about eligibility, technical requirements, review process, pricing, and timelines. Do not advertise “zero data” until the operator confirms the agreement and it is tested on eligible SIMs/plans. HTTPS, third-party assets, DNS, and API endpoints may need explicit inclusion.

### Acceptance criteria

- A throttled/briefly disconnected client can queue an eligible action and reconcile it without duplicate records.
- Urgent actions are never delayed by a scheduled sync window.
- The UI accurately distinguishes local pending state from server-confirmed state.
- Network usage is measured in tests before and after optimization.
- Zero-rating status is labelled **Partnership pending** until contract and operator-side verification are complete.

## 2. High-trust audit and anti-fraud rails

### Audit event model

Create a tenant-scoped append-only event stream for material business actions, including actor/profile, organization, action, entity type/id, server timestamp, request/correlation ID, outcome, and a minimal before/after diff. Record approval decisions, role/permission changes, inventory movements, invoice edits, supplier changes, and failed/overdue approval transitions where supported.

- Write events in the same database transaction as the business mutation, preferably through guarded RPCs/triggers.
- Revoke UPDATE/DELETE privileges on audit rows from normal application roles; enforce RLS and restrict retention/export administration.
- Do not store passwords, access tokens, full payment credentials, or unnecessary personal data in event payloads.
- Consider hash chaining and periodic signed checkpoints for tamper evidence; do not call logs absolutely immutable unless privileged database/admin tampering is also addressed.
- Provide filtered search and CSV/PDF export for authorized auditors, with access to the audit log itself also audited.

### Field-task verification

- Make geolocation an explicit organization policy for selected task categories, not a blanket requirement for all staff.
- Request browser/device location only at the task milestone that requires it; explain purpose and retention, and allow a documented exception path for denied permission, GPS outage, or safety concerns.
- Store coordinates only when necessary, along with accuracy radius, capture time, task/site ID, and actor. Restrict access and configure retention.
- Compare the reported point to an organization-defined site geofence and show **Within site**, **Outside site**, or **Unable to verify** with accuracy and timestamp.
- Treat browser GPS as evidence, not proof: it can be spoofed. Higher-assurance deployments may require device attestation, supervisor confirmation, photo evidence, or a signed QR/NFC site marker.
- Never infer misconduct automatically from one location mismatch. Preserve a review/appeal workflow and audit any override.

### Acceptance criteria

- Unauthorized users cannot read another tenant's audit events or precise location evidence.
- Ordinary users cannot edit or delete historic audit entries through application APIs.
- Every supported critical mutation produces one corresponding event; rollback leaves no false event.
- Geofence failures and unavailable location are distinguishable, reviewable states rather than silently successful check-ins.

## 3. Statutory document preparation and compliance deadlines

### Compliance register

Model obligations as configurable records with country, jurisdiction, authority, obligation type, recurrence, due-date rule, owner, reviewer, lead-time reminders, status, evidence links, and last verified source/version. Support organization-specific licences, tax returns, payroll deductions, and renewal dates. Use timezone-aware deadlines and business-day calendars where relevant.

- Default reminders should be configurable (for example 30/14/7/1 days), with escalation to a backup owner.
- Make missed deadlines visible on the control tower; track acknowledgment, preparation, review, submission reference, and authority-confirmed acceptance as distinct states.
- Keep an effective-dated source register for each jurisdiction and require review by a qualified local tax/compliance professional before a rule is marked production-approved.
- Provide exportable workpapers and templates before attempting direct authority APIs. Generated documents must be labelled **Prepared — not filed** until submission is independently confirmed.
- For Kenya, investigate KRA iTax and relevant company/employee statutory requirements using current official guidance. For South Africa, separately validate SARS formats and requirements. Do not assume one country's schema or calendar applies to another.
- Do not scrape portals, automate credentials, or claim an official integration without documented authorization and a supported API or approved upload workflow.

### Acceptance criteria

- An admin can add/edit an obligation, assign an owner, configure reminders, and attach evidence.
- A due date or rule change is versioned and leaves an audit event.
- Reminder jobs are idempotent and timezone-tested.
- Country-specific rules are versioned, sourced, and marked verified/unverified.
- A prepared file cannot be confused with a filed or accepted return.

## 4. Five-minute business import

### Import workflow

1. Upload CSV/XLSX; validate file type, size, encoding, sheet count, and headers.
2. Detect likely target entity (employees, contacts, suppliers, inventory, tasks) and offer editable column mapping.
3. Preview normalized rows with row-level warnings/errors and duplicate candidates.
4. Normalize whitespace, phone formats, dates, currency/decimal formats, and common header variants without silently changing business meaning.
5. Validate required fields and tenant ownership; allow users to download an error report.
6. Commit only after an explicit review and confirmation. Use a staging batch ID, idempotency key, and transaction/batch status.
7. Report imported, skipped, rejected, and duplicate rows; allow a controlled rollback before downstream workflows use the records.

### Security and data integrity

- Parse files in a bounded process; reject oversized, malformed, or formula/macro-enabled content not supported by the importer.
- Never execute spreadsheet formulas or macros. Escape spreadsheet formula prefixes when exporting error reports.
- Do not send uploaded company data to external AI services without explicit informed consent and an approved data-processing arrangement.
- Apply RLS and organization-scoped duplicate checks on the server, not just in the browser.
- Treat matching as a suggestion. Do not auto-merge employees, suppliers, or financial records based on a fuzzy match alone.
- Maintain an import audit trail including uploader, source filename, mapping version, counts, errors, and timestamp; avoid retaining raw uploads longer than necessary.

### Acceptance criteria

- A representative messy file can be mapped and previewed before any persistent writes.
- Invalid rows do not silently disappear; every row has an outcome.
- Replaying a batch cannot duplicate successful rows.
- Cross-tenant records are rejected, and sensitive imports require appropriate permissions.
- Usability test target: a typical 100–500-row CSV/XLSX can be mapped and validated in under five minutes on an ordinary connection; actual performance must be measured.

## 5. Local agent and onboarding network

This is a go-to-market programme, not an in-app feature. Pilot in one Kenyan region/industry before expanding.

- Define an agent playbook: discovery, data-readiness checklist, tenant setup, role/approval configuration, import, training, and 30-day adoption check.
- Use a documented commission schedule tied to verified paid subscriptions and retention milestones, not merely account creation.
- Agents must not ask for passwords, collect payment-card credentials, or bypass tenant authorization. Use customer-controlled invitations and role-based access.
- Require customer consent for any data handling; use NDAs/data-processing terms, background checks where appropriate, and a clear offboarding process.
- Track lead source, activation, time-to-first-value, 30/90-day active usage, support burden, churn, and commission reversals for refunds/fraud.
- Publish an escalation path for product defects, data incidents, and compliance questions; agents must not provide unqualified tax/legal advice.

### Pilot exit criteria

- At least one documented industry playbook, training material, customer consent flow, and commission agreement.
- Measure activation and retention against self-serve onboarding; scale only if the cohort economics work.

## Delivery sequence

| Phase | Deliverable | Gate before release |
|---|---|---|
| 0 — baseline | Inventory existing audit schema, RLS, migrations, importer, task and sync behavior | Document actual code paths and test coverage |
| 1 — integrity | Append-only audit coverage for supported critical mutations; tests for tenant isolation | RLS, rollback, permission and duplicate-event tests pass |
| 2 — import | Staging, mapping, preview, validation, commit report and rollback controls | Fixtures for messy CSV/XLSX; malicious/oversized files rejected |
| 3 — compliance | Obligation register, reminders, escalation and source/version register | Local expert validates initial jurisdiction rules |
| 4 — field proof | Opt-in geofence policy and evidence review | Permission, retention, spoofing caveats and exception workflow reviewed |
| 5 — low bandwidth | Queue/retry/idempotency, payload reduction, opt-in scheduled sync | Offline/reconnect and network-usage tests pass |
| Parallel commercial | Telco zero-rating discovery and agent pilot | No claims of availability until signed/verified |

## Required engineering checks before implementation

- Inspect current migrations and existing `audit_events` shape before adding tables or triggers; reuse established conventions where safe.
- Confirm tenant and role checks on every mutation path, not just UI visibility.
- Use migrations for schema changes, add automated tests, and avoid modifying production data during feature development.
- Verify the active Vercel project/build status separately from Git merge status. Previous build-rate-limit failures mean merged code alone does not prove the live site updated.
- Keep external credentials in server-side secrets; no telco, regulator, email, or payment secrets in browser code.
