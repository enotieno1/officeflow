# OfficeFlow 12-Programme Execution Blueprint
**Baseline refreshed:** 2026-11-06  
**Repository:** `enotieno1/officeflow`  
**Production app:** `https://office-sort.vercel.app`  
**Supabase project:** `oghowrilrhummzvrljdt`  
**Execution rule:** Audit → Fix → Test → Verify → Release → Grow.

## Purpose
This is the execution plan for taking the existing OfficeFlow platform to dependable customer use and recurring revenue. It is not a claim that all work is complete. Preserve working functionality, repair incomplete functionality, and build only verified gaps. Production changes require a reviewed implementation, a test plan, a rollback plan and post-deployment verification.

## Fresh infrastructure evidence (2026-11-06)
- Supabase project is `ACTIVE_HEALTHY`, region `eu-west-1`, PostgreSQL `17.6.1.084`.
- 46 public tables; RLS enabled on all 46; 83 policies.
- 99 production migration records are currently returned by Supabase (the earlier register's count of 94 is stale and must be reconciled with Git).
- 7 active Edge Functions: `billing-checkout`, `intasend-webhook`, `officeflow-ai`, `organization-invite`, `payroll-payment-batch`, `mpesa-b2c-readiness`, `social-media-oauth`.
- Database currently reports 30 SECURITY DEFINER functions in public; 28 executable by authenticated and none executable by anon. These counts do not themselves prove a vulnerability; review each function's body, caller checks, grants and tenant scope.
- Security advisor: 2 RLS-enabled social-media tables have no policies. A separate privilege query confirms anon and authenticated have no SELECT/INSERT/UPDATE/DELETE grants on either table. Treat these as intentionally service-role-only unless code review proves otherwise; do not add client policies merely to clear an informational warning.
- Security advisor: 34 GraphQL authenticated-schema exposure warnings. These concern object discoverability through GraphQL when SELECT is granted; they do not by themselves prove row leakage. Review actual app use and RLS before restricting grants.
- Security advisor: 23 authenticated-executable SECURITY DEFINER warnings. Many public wrappers delegate to private functions. Review all 23 and their private implementations before revoking EXECUTE or changing security mode.
- Security advisor: leaked-password protection disabled. Enable through Auth configuration after checking compatibility and recovery/signup experience.
- Performance advisor: 71 unused-index notices. Do not drop indexes from a low-activity database without representative workload and query-plan evidence.
- Health advisor returned no current lints.
- No Supabase development branches are present.
- Production database is PostgreSQL 17.6.1.084, not the generic "17" recorded in the earlier baseline.
- Vercel settings, domain/DNS, backups, restore, monitoring and actual cloud spend have not yet been independently verified through the provider dashboard.

## The 12 programmes

### 1. Product audit and completion
**Status:** In progress.  
**Tasks:**
- Inventory every route, screen, script, API call, database object, role gate and external dependency.
- Build a workflow map from UI → API/RPC/Edge Function → database/storage → authorization → notification/audit.
- Classify each capability as implemented, tested, production-verified, customer-ready, incomplete, blocked or unknown.
- Map all nine modules and remove duplicate or obsolete navigation only after dependency checks.
**Acceptance:** Complete evidence-backed register; no feature declared complete from UI presence alone.

### 2. Cloud and infrastructure
**Status:** Partially evidenced; provider-level operational controls unknown.  
**Tasks:**
- Verify Vercel project, production branch, build command/output, deployment SHA, domains, TLS, redirects, environment variables, previews and rollback.
- Verify Supabase plan, compute, storage, egress, backups, retention, point-in-time recovery eligibility and monthly cost.
- Establish staging separate from production; use synthetic/test data.
- Perform an isolated database and storage restore exercise; record RPO/RTO.
- Verify uptime, frontend/backend, database, Edge Function and webhook monitoring and alert routing.
- Review DNS/CDN/WAF/rate limits and load capacity.
- Assess data residency and cross-border transfer needs before any cloud migration.
- Keep Vercel + Supabase unless measured reliability, cost, compliance or scale evidence supports another provider.
**Acceptance:** Documented topology, cost baseline, backup proof, restore proof, monitoring alerts and rollback test.

### 3. Engineering and release quality
**Status:** Not yet verified.  
**Tasks:** Identify actual framework/build/test commands; add or repair CI; unit, integration, browser E2E and regression suites; dependency and secret scans; migration parity checks; staging deploy; release checklist; rollback. Pin supported tool versions. Review Supabase CLI v3 change: hosted database commands now default local and require explicit `--remote`; update any automation before upgrading CLI.
**Acceptance:** Reproducible clean build, passing automated tests, migration checks and tested deployment rollback.

### 4. Security and compliance
**Status:** Findings open; some findings need contextual triage rather than blanket changes.  
**Tasks:** Review the 23 exposed SECURITY DEFINER functions and their private implementations; verify fixed search_path, explicit caller identity, role checks, tenant predicates and least-privilege EXECUTE. Review GraphQL object exposure and legitimate client dependencies. Confirm service-only access to social-media credential/state tables. Enable leaked-password protection and test signup/recovery. Run two-tenant negative tests, storage tests, session/MFA checks, secret scan, vulnerability assessment and independent penetration test. Establish incident response, retention/deletion, processor register and applicable Kenya/target-market privacy obligations.
**Acceptance:** No unresolved critical/high exploitable findings; cross-tenant and privilege tests pass; security decisions documented.

### 5. Nine core modules
**Status:** Schema/code foundations exist; end-to-end customer readiness unknown.  
**Modules:** HR Management; Finance & Administration; Tasks & Workflow; Document Management; Email & Communication; Calendar & Scheduling; AI Productivity; Reports & Insights; Security & Access.
**Tasks:** For every role and tenant, test create/read/update/approve/reject/export, validation, permissions, persistence, audit, notification, empty/error/loading states and mobile layout. Confirm reports reconcile to underlying records. Do not implement new functionality until the gap is confirmed.
**Acceptance:** Every advertised workflow passes module-specific acceptance tests in staging and selected production smoke tests.

### 6. Integrations and AI
**Status:** Seven Edge Functions active; provider credentials and end-to-end behaviour not yet verified.  
**Tasks:** Review all seven functions; confirm authentication mode is appropriate (webhooks/OAuth callbacks may be unauthenticated at platform JWT layer only if request signature/state validation is robust). Verify transactional email provider and delivery; Google/Microsoft OAuth; IntaSend checkout/webhook signature, idempotency, amount/currency matching and failure/refund cases; AI provider secret, authorization, privacy, quotas and provider-failure handling; M-Pesa B2C readiness and approval; social OAuth state/PKCE/token storage. Document unsupported integrations honestly.
**Acceptance:** Provider sandbox tests and production-safe smoke tests pass; secrets never enter browser bundles/logs; retries are idempotent.

### 7. Commercialisation
**Status:** Billing tables/functions present; live subscription lifecycle not verified.  
**Tasks:** Finalise plan catalogue, included modules, seats/storage/usage entitlements, trial rules, upgrade/downgrade, renewal, failed-payment grace, cancellation, invoice/receipt, tax treatment, refunds and reconciliation. Test payment provider callbacks and duplicate/out-of-order events.
**Acceptance:** Provider-confirmed payment alone activates entitlements; subscription state, invoice and customer-facing status reconcile correctly.

### 8. Customer experience
**Status:** Website and dashboard exist; independent onboarding not verified.  
**Tasks:** Align public messaging and nine-module taxonomy; fix route/navigation/search; responsive mobile/tablet; accessibility and keyboard navigation; trial onboarding; setup checklist; sample/demo data; user/admin guides; help centre; support inbox and escalation; status/maintenance communications.
**Acceptance:** A new organisation can register, configure, invite users, learn core tasks and request help without founder intervention.

### 9. Legal and corporate governance
**Status:** Not verified.  
**Tasks:** Confirm operating entity, ownership and IP assignment; third-party licences; SaaS terms, acceptable use, privacy notice, cookie notice where applicable, data-processing terms, subprocessor list, retention/deletion/export, breach notification, customer contracts, vendor agreements, tax and statutory obligations. Obtain qualified Kenyan legal/privacy review and review target markets before expansion.
**Acceptance:** Approved legal pack and clear accountability for data controller/processor roles and IP.

### 10. Financial sustainability
**Status:** Not verified.  
**Tasks:** Build a model for revenue by plan, payment fees, cloud and AI cost per tenant/user, support and implementation cost, CAC, conversion, MRR, ARR, churn, gross margin, runway and break-even. Track actual cloud spend and set budget alerts.
**Acceptance:** Pricing has positive contribution margin under realistic usage assumptions and operating cash requirements are understood.

### 11. Sales and customer success
**Status:** Not started / not evidenced.  
**Tasks:** Define ideal customer profiles and first segment; prepare demo tenant, discovery script, CRM pipeline, proposal/contract, onboarding checklist, implementation playbook, support SLA, escalation, feedback and renewal process. Recruit 10 pilot organisations only after release gates pass.
**Acceptance:** Pilot cohort activated, usage measured, issues closed, willingness to pay confirmed and conversion evidence recorded.

### 12. Expansion and ecosystem
**Status:** Deferred until product-market evidence.  
**Tasks:** Validate mobile app need, offline/low-data mode, local languages/currencies/tax rules, public API/webhooks, developer docs, integration marketplace, partner/reseller ecosystem and country-specific compliance. Prioritise only from customer demand and unit economics.
**Acceptance:** Expansion decision supported by retention, revenue, reliability and a country/feature business case.

## Execution sequence (gated, not calendar promises)
1. **Baseline and P0 risk triage:** Programmes 1, 2, 3 and 4 read-only inspection; no production changes.
2. **Stabilisation:** resolve verified critical security/data-integrity issues; establish staging, CI, backup/restore and monitoring.
3. **Workflow completion:** Programme 5 module acceptance tests; repair only evidenced gaps.
4. **Commercial foundation:** Programmes 6–10; prove integrations, billing, customer onboarding, legal and unit economics.
5. **Pilot:** Programme 11 after all critical release gates.
6. **Scale:** Programme 12 after measurable product-market evidence.

## Immediate action queue
| ID | Priority | Action | Programme | Exit evidence |
|---|---|---|---|---|
| OF-001 | P0 | Review all authenticated-executable SECURITY DEFINER functions and private delegates | 4 | Function-by-function authorization matrix and tests |
| OF-002 | P0 | Verify two-tenant RLS and storage isolation | 4/5 | Automated negative tests prove no cross-tenant read/write |
| OF-003 | P1 | Reconcile 99 production migrations with repository history | 1/2/3 | Version-by-version parity and drift report |
| OF-004 | P1 | Verify Vercel deployment and production configuration | 2/3 | Deployment SHA, domains, env inventory and rollback evidence |
| OF-005 | P1 | Verify Supabase backup/restore and recovery settings | 2 | Isolated restore evidence and RPO/RTO |
| OF-006 | P1 | Review GraphQL exposure and intended Data API grants | 4 | Documented least-privilege exposure matrix |
| OF-007 | P1 | Enable leaked-password protection after compatibility test | 4 | Auth setting enabled and signup/recovery tests pass |
| OF-008 | P1 | End-to-end test billing and webhook reconciliation | 6/7 | Provider sandbox evidence including duplicate/failure events |
| OF-009 | P1 | Verify transactional email and invitation lifecycle | 6/8 | Received email and completed invitation acceptance |
| OF-010 | P2 | Build nine-module role/tenant workflow matrix | 1/5 | Passed acceptance cases for every advertised workflow |

## Change-control rules
- Read-only audit first. Do not change production RLS, grants, functions, schema, secrets or cloud provider settings without a reviewed remediation and rollback plan.
- Never add permissive RLS policies just to silence advisors.
- Never revoke privileges or change SECURITY DEFINER to INVOKER without tracing app dependencies and testing the caller paths.
- Never expose service-role/secret keys to browser code.
- No production deploy based solely on a successful build.
- Each completed task must record test evidence, date, commit/deployment SHA and rollback path.
- P0 security, tenant-isolation, payment-integrity or data-loss failures block commercial launch.


## Edge Function source review — 2026-11-06
All seven deployed Edge Functions were enumerated and their deployed source inspected read-only:
- `billing-checkout`: platform JWT verification enabled; code calls `auth.getUser()` using the caller's bearer token. Its CORS default is `https://officeflow.co.ke`, while the known live application URL is `https://office-sort.vercel.app`; actual deployed `APP_ORIGIN` and `APP_BASE_URL` secrets/config values are not visible through this inspection and must be verified.
- `intasend-webhook`: platform JWT verification disabled; source checks a configured webhook challenge and independently fetches payment status from IntaSend before calling database reconciliation. Verify provider's current webhook verification contract and test replay/out-of-order/failure cases.
- `officeflow-ai`: platform JWT verification disabled but source manually calls Supabase Auth `/auth/v1/user` to validate the bearer token. It returns 503 when `OPENAI_API_KEY` is absent. CORS currently allows `*`; confirm explicit auth and restrict browser origin to approved production/preview origins.
- `organization-invite`: platform JWT verification enabled; source validates bearer token via `auth.getUser()` and defaults APP_BASE_URL to the current known live app URL.
- `payroll-payment-batch`: platform JWT verification enabled; source validates the caller via Supabase Auth. CORS currently allows `*`; restrict to approved browser origins after testing.
- `mpesa-b2c-readiness`: platform JWT verification enabled; source validates the caller via Supabase Auth. CORS currently allows `*`; restrict to approved browser origins after testing.
- `social-media-oauth`: platform JWT verification disabled to support OAuth callback flow; source uses state hash/expiry and provider authorization-code flow with PKCE-related handling. Verify state one-time use, provider-specific PKCE, callback URLs and secret storage end to end.

This is source inspection, not a successful provider integration test. No Edge Function was redeployed and no secrets were read or changed. Tracking issue: [#63](https://github.com/enotieno1/officeflow/issues/63).
