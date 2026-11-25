# OfficeFlow Feature Coverage Checklist
**Review basis:** repository evidence and the readiness matrix; no live production verification performed for this checklist.  
**Rule:** a page, button, table or function is not proof of a working customer workflow.

## Status definitions
- [ ] Not inspected
- [~] Present in repository / partial; end-to-end verification outstanding
- [x] Verified by recorded test evidence (attach evidence and date)

## Nine core modules

### 1. HR Management
- [~] HR interface and employee-related records exist.
- [ ] Create, edit, view and deactivate employee through authenticated workflow.
- [ ] Validate organization and department boundaries.
- [ ] Verify confidential salary/personnel fields are restricted.
- [ ] Verify leave request, approval, balance and audit history.
- [ ] Verify onboarding/offboarding and access revocation.
- [ ] Verify mobile use and failure states.

### 2. Finance & Administration
- [~] Finance screens and transaction-related records exist.
- [ ] Validate create/review/approve/reject/reverse lifecycle.
- [ ] Verify maker-checker and approval thresholds.
- [ ] Reconcile totals against source records and filters.
- [ ] Verify budget vs actual and vendor/expense workflows.
- [ ] Verify role and department access.
- [ ] Validate accounting/tax boundaries before describing statutory compliance.

### 3. Tasks & Workflow
- [~] Workflow definitions, requests, steps, tasks, comments and audit foundations exist.
- [ ] Repair task create form selector/handler mismatch.
- [ ] Replace hard-coded example cards with live records.
- [ ] Complete task detail and edit journeys.
- [ ] Implement and test export.
- [ ] Verify assignment, reassignment, due dates, completion and reopen controls.
- [ ] Reconcile My Work counts with dashboard/control-tower counts.
- [ ] Test approvals, escalation, notification and audit as one journey.
- [ ] Test cross-tenant and wrong-role denial.

### 4. Document Management
- [~] Document UI and metadata records exist.
- [ ] Upload actual file to private storage.
- [ ] Retrieve with short-lived authorized link.
- [ ] Test revoked access and cross-tenant URL denial.
- [ ] Verify metadata, search, categories, versioning and retention.
- [ ] Verify OCR/extraction result and failure state if enabled.
- [ ] Audit upload, download, share, update and delete.

### 5. Email & Communication
- [~] Outbox/notification foundation and communication screens exist.
- [ ] Configure production email provider and sender authentication.
- [ ] Test invitation, confirmation, reset and operational notification delivery.
- [ ] Verify bounce, retry, rate-limit and delivery error handling.
- [ ] Distinguish in-app notification from external email delivery.
- [ ] Verify tenant branding and recipient privacy.

### 6. Calendar & Scheduling
- [~] Calendar page exists; current readiness matrix records redirect/no persistent event table.
- [ ] Implement persistent event model and RLS.
- [ ] Create, edit, cancel and list events.
- [ ] Verify recurring events, attendees and responses.
- [ ] Verify reminders, timezone handling and conflict detection.
- [ ] Verify private and department calendar permissions.

### 7. AI Productivity
- [~] AI page and gateway foundation exist in project history; provider response not verified.
- [ ] Configure server-side model provider credentials.
- [ ] Verify real provider response from production-like environment.
- [ ] Enforce user/org/department permissions before retrieval.
- [ ] Add source references for grounded summaries.
- [ ] Add human approval for external communications and sensitive decisions.
- [ ] Document retention, training, opt-out, spend limits and prompt-injection controls.
- [ ] Verify rate limits, failure states and usage logs.

### 8. Reports & Insights
- [~] Reports and control-tower surfaces/functions exist.
- [ ] Define every metric and date/time basis.
- [ ] Reconcile metrics to test fixtures and source records.
- [ ] Verify department and role-aware aggregation.
- [ ] Verify exports preserve filters and access scope.
- [ ] Test empty, delayed and partial-data states.
- [ ] Remove or label demo/placeholder metrics.

### 9. Security & Access
- [~] Six-role model, tenant/RLS foundations and audit surfaces are present in project history.
- [ ] Run cross-tenant negative tests for every tenant table and storage path.
- [ ] Run wrong-role and cross-department negative tests.
- [ ] Review SECURITY DEFINER functions and exposed RPCs.
- [ ] Review storage policies and signed URL expiry.
- [ ] Verify MFA, recovery, session revocation and leaked-password protection.
- [ ] Run current Supabase security/performance advisors and close findings.
- [ ] Verify production secrets are server-side and absent from client bundles/logs.

## Commercial foundations
- [ ] New logo and design system consistently applied.
- [ ] Signup, email confirmation, organization setup and invitation tested.
- [ ] Pricing and package entitlements enforced server-side.
- [ ] Subscription checkout, webhook verification, retries and reconciliation tested.
- [ ] Support and privacy contact routes are staffed and accurate.
- [ ] Customer terms, privacy notice, data processing terms and retention policy reviewed.
- [ ] Pilot onboarding and incident escalation documented.
