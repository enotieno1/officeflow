# OfficeFlow — Five-Pillar Operating System Implementation Plan

**Prepared:** 2026-11-08  
**Repository:** `enotieno1/officeflow`  
**Status:** Execution baseline; implementation is gated by the evidence and acceptance criteria below.  
**Product ambition:** Build Africa's leading business operating system, then compete globally.

## Executive product decision

OfficeFlow is to become an **intelligent operating system for organisations**. It must help an organisation run, understand, coordinate and improve its operations from one secure workspace.

The product must not become nine disconnected modules, a collection of AI demonstrations, or a consultancy workflow. The nine modules remain useful entry points into one shared operating environment. Identity, organisation structure, workflows, records, notifications, audit, reporting and intelligence must connect them.

The five pillars below are the product strategy. This plan consolidates and sequences work already described in `PRODUCT_ROADMAP.md`, `PRODUCT_SCOPE_AND_GAP_AUDIT.md`, `AFRICAN_MARKETS_PRODUCT_STRATEGY.md`, `INTELLIGENCE_ECOSYSTEM_IMPLEMENTATION.md`, and `BLUEPRINT_IMPLEMENTATION_BACKLOG.md`. It does not replace their detailed requirements.

## The five pillars

### Pillar 1 — One connected organisational operating system

**Outcome:** An organisation can manage its authorised daily operations through one coherent workspace, with shared identity, departments, records, workflows, tasks, documents, notifications and reporting.

**Implementation work**
1. Keep one authoritative Supabase authentication/session path and the existing six-role model. Do not introduce parallel role systems.
2. Make organisation and department context consistent across every module and server-side operation.
3. Connect module actions to real shared records and workflow state. Navigation links, static dashboards and sample data do not count as integration.
4. Prioritise complete daily journeys: organisation setup and invitations; employee and HR actions; finance requests and approvals; procurement requests; task assignment; document handling; notifications; management reporting.
5. Keep financial accounting, payment execution, payroll disbursement and statutory compliance clearly separated from workflow tracking unless the corresponding service and controls are actually implemented.

**Acceptance evidence**
- A controlled organisation can complete a representative journey from sign-in to record creation, approval, execution/evidence, notification and reporting.
- The same action is visible consistently to users with the appropriate permissions.
- A second test organisation cannot read or mutate the first organisation's data.
- Every module is labelled accurately as verified, partial, blocked, unavailable or not yet implemented.

### Pillar 2 — AI as the intelligence engine

**Outcome:** AI assists authorised users with understanding, drafting, analysing and improving work. It is embedded into real workflows rather than being a standalone chatbot disconnected from organisational data.

**Implementation work**
1. Complete the existing AI gateway hardening before adding new AI experiences. PR #65 is currently a draft and is explicitly not production-approved; its migration, Deno checks, authenticated tests, concurrency tests and real provider request remain release gates.
2. Resolve tenant identity from the authenticated server-side profile. Enforce role, department and record-level access before any contextual data reaches a model.
3. Apply atomic request/token quotas, bounded input/output, timeout handling, idempotency, usage metering, cost controls and safe failure behaviour.
4. Add AI capabilities incrementally to existing work: summaries, drafting, extraction suggestions, explainable operational insights and recommendations.
5. Every AI response must distinguish source facts from inference, show relevant evidence or source references where practical, disclose uncertainty and provide a human review path.
6. Never let AI independently approve payments, payroll, hiring decisions, access changes, legal/compliance determinations or other consequential actions.
7. Record appropriate AI usage and outcomes without logging secrets or unnecessary personal information. Apply retention and deletion rules to prompts and outputs.

**Acceptance evidence**
- Authenticated positive and negative tests prove tenant, role and department boundaries.
- Provider calls, errors, timeouts, quotas and costs are observable and reconciled.
- A real provider request succeeds in a controlled environment.
- A user can inspect, edit, reject or accept a recommendation; no consequential action occurs merely because a model suggested it.
- AI is disabled or clearly reports unavailable when provider configuration, quota or permission checks fail.

**Initial AI scope**
- Workflow summaries and bottleneck explanations using verified workflow timestamps.
- Drafting assistance for tasks, correspondence and document metadata.
- Read-only summaries of records the current user is authorised to see.
- Recommendations with evidence, sample size and confidence/coverage indicators.

Predictive procurement, OCR, voice capture, credit exports and automated agents remain separately gated by data availability, validation, privacy and provider readiness.

### Pillar 3 — Cross-department intelligence

**Outcome:** OfficeFlow can connect authorised information across departments to explain organisational dependencies and surface issues that isolated modules cannot reveal.

**Implementation work**
1. Establish a canonical event and relationship model for requests, tasks, approvals, documents, finance records, HR events and organisational units.
2. Reuse the existing Control Tower and operational-intelligence foundations; first reconcile every KPI to source rows and ensure the same events are not counted inconsistently.
3. Define explicit, testable access rules for cross-department queries. A senior job title or dashboard visibility must not silently grant access to confidential HR, payroll or finance records.
4. Begin with read-only, explainable cross-department signals: delayed approval affecting a procurement deadline; unresolved task linked to a workflow; repeated process delays by workflow or unit.
5. Show the source records, time window, sample size, confidence/coverage and recommended next action.
6. Route proposed actions to an authorised human and preserve the existing workflow approval model.
7. Suppress individual-level comparisons where sample sizes are too small or access is not authorised.

**Acceptance evidence**
- Each displayed insight can be traced to source records and reconciled independently.
- Cross-department queries pass positive and negative permission tests.
- Small or incomplete datasets produce an explicit insufficient-data state, not a fabricated prediction.
- Recommendations do not mutate records until an authorised user confirms the action.
- Audit records capture the recommendation, human decision and resulting workflow event.

**First demonstrator**
A manager with the required permissions sees that an approval is overdue, understands which downstream task or procurement milestone is affected, sees the evidence and responsible workflow owner, and can request an authorised follow-up. No automatic payment, purchase order or approval is executed.

### Pillar 4 — Accountability, security and operational trust

**Outcome:** Every important action has a responsible actor, an authorised path, traceable evidence and a recoverable operational state.

**Implementation work**
1. Preserve server-side authorisation and tenant isolation. Review every exposed table, RPC, Edge Function, view and security-definer function by effective privileges and actual caller checks.
2. Review current Supabase security advisories individually. An advisory is not automatically a breach; document whether exposure is intended and prove the relevant RLS/grant behaviour with tests.
3. Make audit events append-only to ordinary users and capture actor, organisation, action, target, timestamp, correlation/request ID and outcome where appropriate.
4. Use explicit workflow state machines, version checks, idempotency and duplicate protection for consequential operations.
5. Build operational alerting around failures, overdue work, unusual privileged activity and integration outages. Risk signals must be labelled as indicators requiring review, not proof of misconduct.
6. Keep human approval and dual control for high-risk financial, payroll, identity and access operations.
7. Define support access as least-privilege, time-bounded, customer-authorised where required and fully audited.
8. Establish backup/restore, incident response, rollback and customer data export/retention procedures.

**Acceptance evidence**
- Role matrix and tenant-boundary tests pass for each critical action.
- Security-definer functions have reviewed `search_path`, grants, caller checks and tenant scope.
- No unauthorised direct table/RPC route bypasses workflow controls.
- Audit history cannot be edited or deleted by ordinary authenticated users.
- Alerts are deduplicated, explainable and linked to review outcomes.
- Restore and rollback procedures are exercised, not merely documented.

### Pillar 5 — African-first, globally competitive

**Outcome:** OfficeFlow works reliably for African organisations with mobile-first users, constrained connectivity, local payment preferences and country-specific operational requirements—without weakening security or making unsupported compliance claims.

**Implementation work**
1. Treat mobile usability, low bandwidth, low-spec devices and clear recovery states as core requirements. Measure current page weight, request volume and performance before optimisation.
2. Prioritise Kenya launch readiness: M-Pesa subscription collection through approved provider onboarding, verified server-side webhooks, idempotency, reconciliation, receipts and failure handling. Keep live payroll disbursement disabled until separately approved and tested.
3. Build provider adapters so additional African payment, messaging and accounting providers can be added without coupling core business logic to one vendor.
4. Introduce safe offline drafts only for selected low-risk actions. Keep approvals, financial actions, payroll and access changes online and server-authoritative until robust sync controls are proven.
5. Localise currencies, dates, numbers and language through shared configuration. Pilot Kiswahili and French only with human-reviewed translations; add further languages based on validated market demand.
6. Maintain a country-by-country privacy, payroll, tax, invoicing and records-compliance register. Country rules require qualified local review and effective dates.
7. Offer human-backed onboarding and support with realistic service hours, secure escalation and audited support access.
8. Validate product-market fit through a small number of real organisations before accelerating acquisition or regional expansion.

**Acceptance evidence**
- Core journeys pass on representative mobile devices and throttled networks.
- Before/after performance measurements are recorded.
- Offline drafts, if enabled, visibly distinguish local, syncing, synced and failed states; retries do not duplicate records.
- Payment sandbox and webhook tests cover success, failure, timeout, duplicate, reversal and reconciliation.
- Country-specific claims are published only after legal/provider/technical verification.
- A pilot records activation, weekly active use, workflow completion, time-to-approval, support burden and willingness to pay.

## Delivery order and gates

The five pillars are strategic outcomes, not five parallel feature streams. Deliver in this order to avoid building intelligence on top of unreliable records or insecure access.

| Phase | Priority | Deliverable | Exit gate |
|---|---|---|---|
| 0. Evidence baseline | P0 | Current feature register, architecture/data map, role matrix, provider/configuration inventory, security-advisory triage | Every claim has a status and evidence; no production changes are made as part of the audit |
| 1. Trust and core journeys | P0/P1 | Auth consistency, tenant/role tests, onboarding, workflow lifecycle, audit integrity, critical UI error states | Fresh-user and two-tenant journeys pass in a controlled test environment |
| 2. Connected operations | P1/P2 | HR, finance requests, procurement, tasks, documents, notifications and reporting connected to shared workflows | Representative department journeys work end-to-end; no demo data or false-success states |
| 3. AI foundation release | P0/P1 | Complete and verify AI gateway hardening, quotas, permissions, provider calls, usage and cost controls | PR #65 release gates pass in isolated test environment; production release separately approved |
| 4. Explainable intelligence | P1/P2 | Source-reconciled Control Tower, bottleneck insights and first cross-department demonstrator | KPI reconciliation, access tests, sample-size safeguards and human review pass |
| 5. Africa-first launch readiness | P1/P2 | Mobile/performance, M-Pesa subscription lifecycle, support, localization and privacy controls | Provider sandbox, mobile/network, support and country review evidence is recorded |
| 6. Pilot and expansion | P2/P3 | Controlled customer pilot, adoption metrics, feedback and prioritised regional adapters | Pilot success measures met before material expansion spend |

## Current evidence and known starting points

The repository already contains meaningful foundations. They must be reused and verified rather than rebuilt or advertised prematurely.

| Area | Evidence in repository / connected environment | Current interpretation |
|---|---|---|
| Shared operating system | Six-role model, tenant-scoped tables, workflow RPCs, notifications, tasks, documents and Control Tower pages/RPCs | Substantial foundation; complete cross-module customer journeys still require testing |
| AI | `officeflow-ai` Edge Function v2 and AI usage/recommendation/timing schema; PR #65 proposes v3 hardening | Foundation exists; PR #65 remains draft and not production-approved |
| Cross-department intelligence | `fn_control_tower`, `fn_operational_intelligence`, and Control Tower UI | Operational visibility foundation; metric reconciliation and permission-aware cross-domain insights remain gates |
| Accountability | RLS, audit tables, guarded RPCs, fraud-risk work and workflow escalation | Partial; review current GraphQL, security-definer and audit controls with tests |
| Africa-first | Existing African Markets Product Strategy, Intelligence Ecosystem specification and Africa-readiness work | Strategy and some foundations exist; provider activation, offline support, localization and compliance must be verified separately |

**Important:** The current connected Supabase project being healthy and an Edge Function showing as active do not prove an end-to-end customer workflow, successful AI provider call, secure cross-department access, payment collection or production readiness.

## First execution backlog

Work these items before adding broad new AI features:

1. **P0 — AI release gate:** Review PR #65 in detail; complete the isolated migration, Deno, SQL, authenticated tenant/unit, quota/concurrency and real-provider tests. Do not merge or deploy until evidence is recorded.
2. **P0 — Access and exposure review:** Triage current Supabase GraphQL visibility, security-definer execute grants, RLS policies and Edge Function authentication. Test actual access paths; do not apply blanket revocations.
3. **P1 — Control Tower reconciliation:** Compare every displayed KPI with independently calculated source counts for a controlled test organisation and unit.
4. **P1 — Cross-module journey map:** Select one real journey connecting a department request, approval, task, supporting document, notification and management report. Record every missing or simulated step.
5. **P1 — Africa launch baseline:** Measure mobile performance and inventory M-Pesa subscription requirements, provider credentials, webhook verification and reconciliation gaps.
6. **P1 — Product status register:** Update the feature verification matrix with the environment, test identity/role, test date, result and evidence for each completed item.

## Non-negotiable engineering rules

- Completion-first: verify existing capabilities before expanding scope.
- No production migration, Edge Function deployment, payment activation or data mutation without a separate explicit release decision and safe test evidence.
- Preserve working functionality and the existing HR visual design during unrelated work.
- Never invent data, AI insights, delivery status, payment success, provider connectivity or compliance status.
- No cross-tenant or cross-department data access based solely on UI visibility or job title.
- AI proposes and explains; authorised humans approve consequential actions.
- Every feature moves through: **code present → tested in isolation → integrated test passed → production verified → customer-ready**.
- Update the release-readiness register after each milestone, including failures and blockers.

## Definition of success

OfficeFlow succeeds when an organisation can rely on it as the place where work is coordinated and controlled, while its intelligence layer turns authorised operational data into clear, explainable and actionable insight. It must be trusted by African customers first and architected to scale internationally.
