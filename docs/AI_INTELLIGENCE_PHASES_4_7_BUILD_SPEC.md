# OfficeFlow AI & Intelligence — Directive Phases 4–7 Build Specification

**Branch:** `ai-intelligence/phases-4-7-foundation`  
**Depends on:** AI gateway hardening in PR #65  
**Status:** Engineering specification; no production deployment authorised.

## Product outcome

Build four connected capabilities: secure AI infrastructure, contextual AI inside the nine OfficeFlow modules, explainable organisation-wide intelligence, and governed AI agents. This is an implementation programme, not a chatbot redesign. Existing workflows, six-role authorisation, tenant isolation, audit and Control Tower foundations must be reused.

## Non-negotiable architecture

1. **Identity:** derive user and organisation from the validated Supabase session and `profiles`; never accept tenant identity or role claims from the browser or model.
2. **Authorisation:** perform data reads with the caller's JWT so existing RLS and unit scope apply. Do not use service-role credentials for model grounding.
3. **Trusted writes:** service-role credentials stay server-side and may only call narrowly scoped, ownership-validating reservation/finalisation/agent functions.
4. **Evidence:** every organisational claim must carry source identifiers, query window, sample size and limitations. Distinguish facts, calculations, inference and recommendations.
5. **Human control:** agents may read, analyse, draft and prepare actions. They may not independently approve payments, payroll, hiring, access changes, legal determinations or other consequential actions.
6. **Privacy:** minimise data before provider calls; exclude salary, health, disciplinary and other sensitive HR attributes from generic management intelligence. Never log prompts, completions, credentials or unnecessary personal data.
7. **Failure honesty:** missing provider keys, insufficient data, denied permissions, quota exhaustion and provider failures produce explicit unavailable/error states. Never substitute fabricated answers or sample metrics.
8. **Release discipline:** build on an isolated GitHub branch; no production migrations, Edge Function replacement, secret changes or deployment without a separately approved release gate.

## Phase 4 — AI infrastructure

### Deliverables
- Harden the existing `officeflow-ai` gateway using PR #65 as the starting point.
- Enforce platform JWT verification after authenticated end-to-end compatibility tests.
- Atomic idempotent request reservations; per-user and per-organisation request limits; token reservation and finalisation; usage, latency and provider-error metering.
- Provider adapter interface, explicit model allowlist, bounded input/output, timeout and retry policy.
- Strict origin allowlist, no-store responses, generic client errors and protected diagnostics.
- Server-side feature registry defining required permission, permitted sources, data classification, output schema and human-review requirement.
- Provider pricing remains unknown until independently verified; no invented cost figures.

### Acceptance
- Positive and negative auth tests, tenant and unit isolation tests, concurrent quota tests, duplicate request tests, provider timeout/failure tests and real provider request all pass.
- Direct browser execution of trusted reservation/finalisation/recommendation functions is denied.
- No prompt/completion/secret appears in logs.
- AI cannot run when configuration or permission checks fail.

## Phase 5 — Module-level AI

Embed contextual assistance into the nine existing modules, using real authorised records rather than generic prompt-only experiences.

| Module | Initial AI capability | Data boundary |
|---|---|---|
| HR Management | Aggregate workforce summaries, leave/workload explanations, HR drafting | HR-authorised users; suppress sensitive employee-level data |
| Finance & Administration | Expense/transaction categorisation suggestions, variance explanations, anomaly leads | Finance-authorised records only; never execute payments |
| Tasks & Workflow | Task summaries, overdue-work explanations, workflow bottleneck analysis | Assigned work and authorised unit/org aggregates |
| Document Management | User-supplied/extracted text summaries, metadata suggestions, classification proposals | Document ACLs and sensitivity labels |
| Email & Communication | Draft, rewrite, summarise supplied/authorised threads | Explicitly connected and authorised content only |
| Calendar & Scheduling | Meeting preparation, schedule conflict explanations, agenda drafts | Calendar ACLs; no silent invitations or changes |
| AI Productivity | Cross-module assistant, task breakdown and knowledge assistance | Same caller permissions as each source |
| Reports & Insights | Explain verified reports, trends and metric definitions | Report-level access and source lineage |
| Security & Access | Explain access events and policy configuration; flag suspicious patterns | Security/audit permissions; no automatic role changes |

Each capability must have a source contract, permission tests, sample-size safeguards, evidence display and a human review path. Do not enable a module capability merely because its button or prompt exists.

## Phase 6 — Organisational intelligence

### Canonical intelligence model
- Reuse source records and existing workflow, task, document, finance, HR, notification and audit events.
- Establish a canonical event/relationship map with organisation, unit, actor, entity, event type, timestamp, correlation ID and source record.
- Build permission-aware aggregate queries and metric definitions before adding model interpretation.
- Reconcile Control Tower metrics against independent source-row counts.
- Add cross-department dependency signals, beginning with overdue approval → blocked task/procurement milestone.
- Show evidence, date window, sample size, coverage, confidence/limitations and suggested next action.
- Suppress small-sample and unauthorised individual comparisons; no confidential HR leakage into general management views.

### Acceptance
- Every insight can be independently traced to source records and recomputed.
- Cross-tenant, cross-unit and sensitive-department negative tests pass.
- Insufficient or stale data is explicitly labelled.
- Recommendations do not mutate business records until an authorised user confirms them.
- Recommendation, decision and resulting workflow event are auditable.

## Phase 7 — Governed AI agents

### Agent architecture
- Agent registry: organisation-owned agent definitions, purpose, enabled state, version, allowed tools, scope and approval policy.
- Run ledger: requester, organisation, unit scope, trigger, input references, status, idempotency key, timestamps and outcome.
- Step ledger: ordered plan, tool call, validated arguments, result reference, retry count and error.
- Tool registry: typed allowlisted tools only; no arbitrary SQL, shell, browser execution or model-generated code.
- Policy engine: re-check user/agent permission and record scope at execution time, not only at planning time.
- Approval queue: human approval for all state-changing actions; dual approval for high-risk financial, payroll, identity and access operations.
- Execution adapter: invoke existing OfficeFlow workflow RPCs and state machines; never write around them.
- Kill switch, per-agent quotas, bounded steps, timeout, retry/idempotency, audit trail and replay-safe failure handling.

### Initial agents
1. Workflow Follow-up Agent — identify overdue authorised workflow steps and prepare follow-up drafts.
2. Document Intake Agent — propose metadata/classification from authorised document text for human confirmation.
3. Finance Review Agent — prepare variance/anomaly review packs; no payments or ledger mutation.
4. HR Operations Agent — prepare leave/workforce summaries for HR-authorised reviewers; no hiring, disciplinary or payroll decisions.
5. Executive Briefing Agent — compile permission-filtered organisational summaries with source evidence.

### Agent lifecycle
`requested → planned → awaiting_approval (if action proposed) → approved/rejected → executing → completed/failed/cancelled`

No agent may self-approve. Approval is bound to the exact plan/tool arguments; any material change requires renewed approval. All execution must be idempotent and audited.

### Acceptance
- Cross-tenant and role-scope denial tests pass.
- Unapproved or altered plans cannot execute.
- Duplicate/replayed runs do not duplicate side effects.
- Kill switch and cancellation are effective.
- Every step is attributable and reviewable.
- Consequential operations remain behind existing OfficeFlow approval controls.

## Delivery sequence

1. Complete PR #65 release gate and establish isolated Supabase test environment.
2. Implement feature registry and one end-to-end grounded capability (Tasks & Workflow) as the reference pattern.
3. Add Finance and HR capabilities only after their aggregate source contracts and permission boundaries are tested.
4. Add remaining module capabilities incrementally.
5. Reconcile Control Tower metrics and deliver the first cross-department dependency insight.
6. Add agent registry, run/step ledgers, approval queue and read-only/draft agents.
7. Add narrowly scoped execution adapters only after replay, approval, audit and permission tests pass.

## Current verified baseline (2026-11-25)

- Supabase project is active and healthy.
- `officeflow-ai` is active at version 3; deployed `verify_jwt` is currently false and must be reviewed before extension.
- `ai_usage_log` and `ai_recommendations` exist.
- Existing AI gateway has six feature labels, but live module grounding is limited; workflow grounding calls `fn_ai_workflow_timing` and `fn_operational_intelligence`.
- The AI dashboard still has setup/empty states and browser-local preferences.
- PR #65 contains proposed hardening but remains a draft and is not production-approved.
- Existing Control Tower and operational-intelligence RPCs are foundations, not proof of reconciled cross-department intelligence.
- No agent registry, governed run/step ledger or agent approval framework was found in the inspected public schema.

This baseline is evidence, not a completion claim. Update it after each test and implementation milestone.
