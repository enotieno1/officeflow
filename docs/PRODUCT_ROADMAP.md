# OfficeFlow Product Roadmap
**Baseline:** Audit on 2026-10-19. Priorities are based on evidence in `docs/PRODUCT_SCOPE_AND_GAP_AUDIT.md`, not on feature-page presence.

## P0 — Security and data integrity
1. Review the 15 Supabase GraphQL schema visibility findings for public objects. For each object, decide whether authenticated GraphQL discovery is intended, verify RLS policies and grants, and test cross-tenant access. Avoid blanket revokes that break required functions.
2. Expand automated checks to cover NULL values, partitioned tables, effective privileges, role inheritance and organization consistency.
3. Test all security-definer RPCs: EXECUTE grants, fixed search_path, caller authorization, tenant scoping and error behavior.
4. Confirm audit event write paths are append-only for authenticated clients.
**Exit criteria:** all findings are either remediated or documented as intentionally exposed with tests; no cross-tenant read/write succeeds.

## P1 — Make a coherent core product usable
1. **Authentication consistency:** remove reliance on localStorage-only guards; use Supabase Auth/session as the authority on all protected pages. Audit `dashboard/package-selection.html`, legacy pages and redirect loops.
2. **Onboarding end to end:** fresh signup, profile provision, organization creation, administrator role, department setup, invite/add users and first workflow.
3. **Workflow lifecycle tests:** submit, assign, approve, reject, return, resubmit, cancel, comments, audit trail and version stability with separate accounts.
4. **Control Tower correctness:** compare totals, overdue/escalated counts, unit attribution, average age and bottleneck results to controlled fixture data.
5. **Notifications:** test in-app assignment, decision and escalation alerts. Establish an email provider and sender worker only after required credentials and delivery configuration are available.
6. **Commercial gate:** design subscriptions and entitlements. Do not collect money until a provider-backed checkout, signed webhook verification, idempotency, renewal/cancellation and support/refund process are implemented.
7. **Pilot:** run one organization with Leave and Procurement (or other agreed workflows); measure time-to-approval, completion rate, overdue rate and user adoption.

## P2 — Integrated daily office operations
1. HR: employee records plus leave, onboarding/offboarding and staff changes.
2. Finance: expenses, purchase/payment requests, invoice review and budget approval. Clearly distinguish workflow control from a full accounting ledger.
3. Procurement: requisition, quotation comparison, supplier selection, purchase order and receipt evidence.
4. Tasks: assignment, owner, due date, priority, status transitions, completion evidence and escalation.
5. Documents: secure storage, upload/download, access policy, versioning and retention.
6. Automation: supported event triggers, safe conditions/actions, run history, retries and duplicate protection.
7. Reports: validated operational and departmental reports; export and audit.
8. Mobile/accessibility: responsive smoke tests, keyboard support and error-state polish.

## P3 — Expansion
1. Provider-backed accounting, email/messaging and document-storage integrations.
2. Google/Microsoft SSO where customer demand justifies it.
3. Advanced delegated approvals, compliance exports and enterprise reporting.
4. Usage metering, customer support tools and regional expansion.

## Delivery discipline
- Work in small changes with automated tests.
- Use a staging/test organization for data-mutating tests.
- Do not reset production data or run destructive migrations to simplify tests.
- Each feature must have an acceptance test and evidence before being marked VERIFIED.
- Keep the six roles unchanged: employee, officer, manager, administrator, auditor, super_admin.
- Update the gap register after each milestone; do not mark a milestone complete based on UI appearance alone.
