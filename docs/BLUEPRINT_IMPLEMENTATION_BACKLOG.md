# OfficeFlow Blueprint Review and Implementation Backlog

**Source:** `officeflow_implementation_blueprint.md` supplied for review, October 2026  
**Repository:** `enotieno1/officeflow`  
**Status:** Requirements decomposed; implementation must be verified item by item.

## Review decisions

The blueprint is the source for requirements in this backlog. The following refinements are required before implementation:

1. **Do not promise 100% local operational success.** Browser storage can be cleared, devices can fail, and some actions require authoritative server validation. Define supported offline actions and measurable recovery objectives instead.
2. **Do not adopt Last-Write-Wins globally.** It may be suitable for some low-risk drafts, but not for approvals, payroll, finance or permission changes. Use append-only events, optimistic concurrency/version checks and server-side state-machine validation for critical operations.
3. **Do not force binary serialization everywhere.** Measure real payloads first. For current HTML/Supabase workflows, bounded queries, pagination, selective fields, compression, caching and delta sync are lower-risk first steps. Add Protobuf/MessagePack only when measured benefit justifies complexity.
4. **Treat 150 MB as a target to measure, not an assumed guarantee.** Benchmark representative low-spec devices and constrained browsers.
5. **Offline OCR is a scoped capability, not an existing verified feature.** Test model download size, device performance, language support, accuracy, and privacy before rollout.
6. **Approvals over WhatsApp/SMS must not be authorized by a guessable or reusable command link/hash.** Use short-lived, signed, single-use action tokens, identity checks, expiry, replay protection, audit logging and a secure fallback to the authenticated app. High-risk actions should require authenticated confirmation.
7. **Do not select payment aggregators by example alone.** Compare commercial availability, official API support, country coverage, fees, settlement, refunds, webhook signatures and onboarding. Do not activate real payment or payroll transfers without verified credentials and explicit authorization.
8. **Do not implement automatic tenant read-only downgrades without policy design.** Provide notice, grace period, data export/access continuity and a transparent billing state. Never delete customer data due to a failed renewal.
9. **Compliance needs a country-by-country review.** Validate current law and local advice; do not assume NDPR is the current sole Nigerian privacy framework, and do not promise data residency unless hosting and subprocessors support it.
10. **Support diagnostics must be minimized and consent-based.** Never auto-send access tokens, personal records, document contents, payment details or secrets through WhatsApp.

## Current capability rule

The presence of a page or script does not prove the capability works in production. In particular, existing OCR scripts, workflow pages, payment screens, email drafts, or styled dashboards must be tested against actual backend behavior before being labelled operational. This document does not assert that these capabilities have been implemented.

## Prioritized implementation backlog

### P0 — Establish a verified baseline
- Inventory all current pages, database tables, migrations, RPCs, Edge Functions, storage policies, provider settings and deployment workflows.
- Map critical user journeys and role/tenant access rules.
- Add a feature-status register: live and verified / live but unverified / demo or seeded / disconnected / unavailable.
- Test RLS and direct API/RPC calls for cross-tenant access, role escalation and unauthenticated access.
- Measure page weight, request count, query volume, startup time and memory on representative low-spec devices.
- Define test evidence and release gates. Preserve HR visual design and existing stable workflows.

**Exit criteria:** baseline report with reproduction steps, tests actually run, severity and named next actions; no claim of a full audit unless the full scope was inspected.

### P1 — Low-bandwidth and mobile usability
- Optimize existing HTML delivery: remove unnecessary blocking assets, load noncritical assets only when needed, avoid oversized fonts/images and avoid repeated database fetches.
- Select only needed database fields; paginate and filter large lists server-side.
- Review caching headers for public static assets only. Never service-worker-cache authenticated HTML/API responses by default.
- Fix mobile forms, tables, modals, navigation, touch targets and empty/loading/offline/error states.
- Add performance measurement and documented budgets before deeper serialization changes.

**Exit criteria:** before/after measurements, mobile browser tests, network-throttling tests and no sensitive-data cache regression.

### P2 — Safe offline drafts and synchronization
- Choose the first low-risk use cases, such as task notes or draft form input, after inspecting the current schema and user journeys.
- Define per-record schema/version, local retention, logout cleanup, conflict policy, outbox states, retry/backoff, idempotency key and visible sync status.
- Keep approvals, payroll, billing, permission changes and sensitive execution server-authoritative.
- Use version checks and append-only audit events for consequential workflow changes; do not use LWW for these events.
- Add duplicate, reconnect, stale-session, conflict, device storage clearing and interrupted-sync tests.

**Exit criteria:** users can identify unsynced work; retries do not create duplicates; conflicts are surfaced; sensitive data is not stored insecurely; server rejects unauthorized or stale operations.

### P3 — Document capture and OCR
- Inspect the existing document import/OCR flow and determine whether it currently runs offline.
- Prototype a lazily loaded, compressed OCR engine for a small set of document types and supported languages.
- Provide user review/editing of extracted fields; OCR output is a suggestion, not a verified financial record.
- Compress images client-side within quality limits and enforce upload size/type validation.
- Queue upload and server-side processing separately, with retry and tracking IDs.

**Exit criteria:** measured model download, memory and runtime; accuracy test set; explicit consent; offline/online tests; traceable document status and safe upload policy.

### P4 — Workflow state machine and builder
- Define a versioned workflow schema with allowed states/transitions, required role, limits, validation and notification rules.
- Validate every transition server-side, even when initiated from the UI or a message.
- Treat the visual builder as a configuration editor; compile and validate schema before publishing immutable versions.
- Preserve history for published versions and in-flight requests.
- Test unauthorized transitions, duplicate requests, stale versions, SLA escalation and audit completeness.

**Exit criteria:** state-transition tests pass; published configurations are versioned; client cannot bypass approval rules.

### P5 — Communication and support channels
- Establish a provider-adapter interface for email, WhatsApp Business and SMS without claiming connectivity before provider credentials and webhooks are configured.
- Add event-driven notification jobs, delivery status, retries, opt-in/consent and template approval handling.
- For high-risk actions, message links must expire, be single-use, resist replay and return the user to an authenticated confirmation flow.
- Create a human support queue with severity, owner, status, response target and restricted diagnostic context.
- Never send secrets or full personal records to support channels.

**Exit criteria:** provider sandbox tests, signature verification where supported, idempotent webhook handling, delivery/failure monitoring, audit records and support escalation tests.

### P6 — Payments and monetization
- Implement provider adapters only after confirming commercial onboarding and API contracts.
- Use server-generated idempotency keys and persistent payment-attempt records; validate callbacks/webhooks server-side and reconcile with provider transaction status.
- Separate subscription entitlements from browser redirect results.
- Define monthly baseline pricing first; evaluate weekly and metered models using interviews and unit economics.
- Model grace period, read-only access, cancellation, refunds, reversals, receipts and reconciliation.
- Keep payroll disbursement and other real transfers disabled until verified credentials, approvals, limits and end-to-end tests exist.

**Exit criteria:** sandbox success/failure/timeout/duplicate/reversal tests, reconciliation evidence, provider approval and explicitly authorized production activation.

### P7 — Country localization and compliance
- Maintain a country-specific compliance register and effective-dated tax configuration.
- Confirm applicable privacy, controller/processor, registration, retention, transfer, breach, payroll and invoicing requirements with qualified local advisers.
- Implement locale-aware currency, dates, number formats and translation keys.
- Pilot Kiswahili and French based on demand; add Arabic with right-to-left testing and Portuguese when the market plan justifies them.
- Document actual hosting region and subprocessors; do not promise residency without evidence.

**Exit criteria:** reviewed legal checklist, tested locale coverage, versioned rules and a documented data map/retention process for each launched market.

### P8 — Production quality and observability
- Automate unit, integration, authorization/RLS, end-to-end, responsive and accessibility tests.
- Add structured logs, request IDs, error/latency metrics and alerts with personal data and secrets redacted.
- Establish backup and restore drills, rollback runbooks and incident response.
- Test load and resource usage before publishing scalability or availability claims.

**Exit criteria:** CI results retained, alerts tested, recovery drill completed and production deployment independently verified.

## Implementation reporting template

For every delivered task record:
- Requirement and acceptance criteria
- Files/migrations/functions changed
- Commit identifier
- Environment tested
- Commands and tests actually run
- Observed results
- Security and rollback review
- Remaining blockers, required credentials, legal decisions and limitations
- Deployment status, verified separately from the commit

## Explicitly not authorized by this backlog alone

- Real payments, refunds or payroll transfers
- Unreviewed tax/payroll rules
- Automatic data residency promises
- Broad offline caching of authenticated pages or sensitive documents
- Approval by unauthenticated, reusable SMS/WhatsApp links
- Claiming any feature is production-ready without recorded verification
